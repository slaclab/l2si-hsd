-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-09-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
-- BRAM interface factored out.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library lcls_timing_core;
--use lcls_timing_core.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.FexAlgPkg.all;
use work.FmcPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity QuadAdcEvent is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    NFMC_G            : integer := 2;
    SYNC_BITS_G       : integer := 4;
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C       : slv(31 downto 0) := (others=>'0') );
  port (
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    --
    eventClk    :  in sl;
    trigArm     :  in sl;
    triggerData :  in TriggerEventDataType;
    --
    adcClk     :  in sl;
    adcRst     :  in sl;
    configA    :  in QuadAdcConfigType;
    trigIn     :  in slv         (ROW_SIZE-1 downto 0);
    adc        :  in AdcDataArray(4*NFMC_G-1 downto 0);
    --
    dmaClk        :  in sl;
    dmaRst        :  in sl;
    eventHeader   :  in Slv192Array(NFMC_G-1 downto 0);
    eventHeaderV  :  in slv        (NFMC_G-1 downto 0);
    noPayload     :  in slv        (NFMC_G-1 downto 0);
    eventHeaderRd : out slv        (NFMC_G-1 downto 0);
    rstFifo       :  in sl;
--    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS      : out sl;
    dmaFullCnt    : out slv(31 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    debug         : out Slv8Array           (NFMC_G-1 downto 0);
    dmaMaster     : out AxiStreamMasterArray(NFMC_G-1 downto 0);
    dmaSlave      : in  AxiStreamSlaveArray (NFMC_G-1 downto 0) );
end QuadAdcEvent;

architecture mapping of QuadAdcEvent is

  constant NCHAN_C : integer := 4*NFMC_G;
  
  type EventStateType is (E_IDLE, E_SYNC);
  -- wait enough timingClks for adcSync to latch and settle
  constant T_SYNC : integer := 10;

  type EventRegType is record
    state    : EventStateType;
    delay    : slv( 25 downto 0);
    hdrWr    : slv(  1 downto 0);
    hdrData  : slv(255 downto 0);
  end record;
  constant EVENT_REG_INIT_C : EventRegType := (
    state    => E_IDLE,
    delay    => (others=>'0'),
    hdrWr    => (others=>'0'),
    hdrData  => (others=>'0') );

  signal re    : EventRegType := EVENT_REG_INIT_C;
  signal re_in : EventRegType;

  signal afull  : sl;
  signal afullCnt  : slv(31 downto 0);
  signal ql1in  : sl;
  signal ql1ina : sl;
  signal sl0tag : slv(4 downto 0);
  signal sl1tag : slv(4 downto 0);
  signal shift  : slv(31 downto 0);
  signal clear  : sl;
  signal start  : sl;

  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  
  -- interleave payload
  type AdcIlvChanArray is array(natural range<>) of AdcWordArray(4*ROW_SIZE-1 downto 0);
  signal iadc        : AdcIlvChanArray     (NFMC_G-1 downto 0);
  signal ilvmasters  : AxiStreamMasterArray(NFMC_G-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal ilvslaves   : AxiStreamSlaveArray (NFMC_G-1 downto 0) := (others=>AXI_STREAM_SLAVE_INIT_C);
  signal ilvafull       : slv(NFMC_G-1 downto 0);

  signal hdrValid  : slv(NFMC_G-1 downto 0);
  signal hdrRd     : slv(NFMC_G-1 downto 0);
  
  signal pllSync   : Slv32Array (NFMC_G-1 downto 0);
  signal pllSyncV  : slv        (NFMC_G-1 downto 0);
  signal eventHdr  : Slv256Array(NFMC_G-1 downto 0);

  constant APPLY_SHIFT_C : boolean := false;
  constant NAXIL_C    : integer := NFMC_G;
  
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NAXIL_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NAXIL_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NAXIL_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NAXIL_C-1 downto 0);

  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NAXIL_C-1 downto 0) := genAxiLiteConfig(NAXIL_C, BASE_ADDR_C, 15, 12);

  constant NSTREAMS_C : integer := FEX_ALGORITHMS'length;
  constant NRAM_C     : integer := 4 * NFMC_G * NSTREAMS_C;
  signal bramWr    : BRamWriteMasterArray(NRAM_C-1 downto 0);
  signal bramRd    : BRamReadMasterArray (NRAM_C-1 downto 0);
  signal bRamSl    : BRamReadSlaveArray  (NRAM_C-1 downto 0);

  signal cacheStatus : CacheStatusArray(NFMC_G*MAX_STREAMS_C-1 downto 0);
  signal acqEnable   : slv(NFMC_G-1 downto 0);

  constant DEBUG_C : boolean := true;

  component ila_0
    port ( clk     : in sl;
           probe0  : in slv(255 downto 0) );
  end component;

begin  -- mapping

  GEN_DEBUG : if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk                    => dmaClk,
                 probe0(0)              => dmaRst,
                 probe0(2 downto 1)     => hdrValid (1 downto 0),
                 probe0(4 downto 3)     => noPayload(1 downto 0),
                 probe0(6 downto 5)     => hdrRd    (1 downto 0),
                 probe0(134 downto 7)   => eventHeader(0)(127 downto 0),
                 probe0(255 downto 135) => (others=>'0') );
  end generate;
  
  status     <= cacheStatus(0);
  dmaFullS   <= afull;
  dmaFullCnt <= afullCnt;

  GEN_AXIL_XBAR : entity surf.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G   => 1,
                  NUM_MASTER_SLOTS_G  => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G    => AXIL_XBAR_CONFIG_C )
    port map ( axiClk              => axilClk,
               axiClkRst           => axilRst,
               sAxiReadMasters (0) => axilReadMaster,
               sAxiReadSlaves  (0) => axilReadSlave,
               sAxiWriteMasters(0) => axilWriteMaster,
               sAxiWriteSlaves (0) => axilWriteSlave,
               mAxiReadMasters     => mAxilReadMasters,
               mAxiReadSlaves      => mAxilReadSlaves,
               mAxiWriteMasters    => mAxilWriteMasters,
               mAxiWriteSlaves     => mAxilWriteSlaves );

--      This is the large buffer.
  GEN_RAM : for i in 0 to NFMC_G-1 generate
    GEN_FMC : for j in 0 to NSTREAMS_C-1 generate
      GEN_CHAN : for k in 0 to 3 generate
        U_RAM : entity surf.SimpleDualPortRam
          generic map ( DATA_WIDTH_G => 16*ROW_SIZE,   -- 64*ROW_SIZE? or 4x RAMs
                        ADDR_WIDTH_G => RAM_ADDR_WIDTH_C )
          port map ( clka   => dmaClk,
                     ena    => '1',
                     wea    => bramWr(k+4*j+4*NSTREAMS_C*i).en,
                     addra  => bramWr(k+4*j+4*NSTREAMS_C*i).addr,
                     dina   => bramWr(k+4*j+4*NSTREAMS_C*i).data,
                     clkb   => dmaClk,
                     enb    => bramRd(k+4*j+4*NSTREAMS_C*i).en,
                     rstb   => dmaRst,
                     addrb  => bramRd(k+4*j+4*NSTREAMS_C*i).addr,
                     doutb  => bramSl(k+4*j+4*NSTREAMS_C*i).data );
      end generate;
    end generate;
  end generate;

  GEN_FMC : for i in 0 to NFMC_G-1 generate

    eventHdr     (i) <= pllSync(i) &
                        toSlv(1,8) & toSlv(0,4) &
                        configA.samples(17 downto 4) & toSlv(0,6) &
                        eventHeader(i);
    
    hdrValid     (i) <= eventHeaderV(i) and (pllSyncV(i) or noPayload(i));
    eventHeaderRd(i) <= hdrRd(i);

    --  interleave --
    GEN_ROW : for j in 0 to ROW_SIZE-1 generate
      GEN_COL : for k in 0 to 3 generate
        iadc         (i)(4*j+k) <= adc(4*i+k).data(j);
      end generate;
    end generate;
    
    U_PllSyncF : entity surf.FifoSync
      generic map ( ADDR_WIDTH_G => 4,
                    DATA_WIDTH_G => 32,
                    FWFT_EN_G    => true )
      port map ( rst    => rstFifo,
                 clk    => dmaClk,
                 wr_en  => start,
                 din    => shift,
                 rd_en  => hdrRd   (i),
                 dout   => pllSync (i),
                 valid  => pllSyncV(i) );

    U_INTLV : entity work.QuadAdcInterleavePacked
      generic map ( BASE_ADDR_C    => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    AXIS_CONFIG_G  => CHN_AXIS_CONFIG_C,
                    IFMC_G         => i,
                    ALGORITHM_G    => FEX_ALGORITHMS,
                    DEBUG_G        => (i<1) )  
      port map ( clk             => dmaClk,
                 rst             => dmaRst,
                 clear           => clear,
                 start           => start,
                 shift           => shift(3 downto 0),
                 din             => iadc          (i),
                 dvalid          => '1',
                 l0tag           => sl0tag,
                 l1tag           => sl1tag,
                 l1in            => ql1in,
                 l1ina           => ql1ina,
                 l1a             => open,
                 l1v             => open,
                 almost_full     => ilvafull      (i),
                 status          => cacheStatus   ((i+1)*MAX_STREAMS_C-1 downto i*MAX_STREAMS_C),
                 debug           => debug         (i),
                 axisMaster      => ilvmasters    (i),
                 axisSlave       => ilvslaves     (i),
                 -- BRAM Interface (dmaClk domain)
                 bramWriteMaster => bramWr((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 bramReadMaster  => bramRd((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 bramReadSlave   => bramSl((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 -- AXI-Lite Interface
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (i),
                 axilReadSlave   => mAxilReadSlaves  (i),
                 axilWriteMaster => mAxilWriteMasters(i),
                 axilWriteSlave  => mAxilWriteSlaves (i) );

    U_DATA : entity work.QuadAdcChannelData
      generic map ( SAXIS_CONFIG_G => CHN_AXIS_CONFIG_C,
                    MAXIS_CONFIG_G => DMA_STREAM_CONFIG_G,
                    DEBUG_G        => (i<1) )
      port map ( dmaClk      => dmaClk,
                 dmaRst      => dmaRst,
                 --
                 eventHdrV   => hdrValid (i),
                 eventHdr    => eventHdr (i),
                 noPayload   => noPayload(i),
                 eventHdrRd  => hdrRd    (i),
                 --
                 chnMaster   => ilvmasters(i),
                 chnSlave    => ilvslaves (i),
                 dmaMaster   => dmaMaster(i),
                 dmaSlave    => dmaSlave (i) );

  end generate;

  acqEnable <= (others=>configA.acqEnable);
  
  U_Trigger : entity work.QuadAdcTrigger
    generic map ( NCHAN_C => NFMC_G )
    port map ( triggerClk  => eventClk,
               triggerRst  => '0',
               triggerData => triggerData,
               --
               clk       => dmaClk,
               rst       => dmaRst,
               trigIn    => trigIn,  
               afullIn   => ilvafull,
               enable    => acqEnable,
               --
               afullOut  => afull,
               afullCnt  => afullCnt,
               ql1in     => ql1in,
               ql1ina    => ql1ina,
               shift     => shift,
               clear     => clear,
               start     => start,
               l0tag     => sl0tag,
               l1tag     => sl1tag );

end mapping;
