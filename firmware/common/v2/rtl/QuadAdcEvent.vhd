-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2019-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
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
use work.FmcPkg.all;
use work.QuadAdcPkg.all;
use work.FexAlgPkg.all;

entity QuadAdcEvent is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    NCHAN_G           : integer := 4;
    SYNC_BITS_G       : integer := 4;
    DMA_SIZE_G        : integer := 4;
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C       : slv(31 downto 0) := (others=>'0') );
  port (
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    --eventClk   :  in sl;
    --eventRst   :  in sl;
    --eventId    :  in slv(127 downto 0);
    --strobe     :  in sl;
    eventClk   :  in sl;
    trigArm    :  in sl;
    l1in       :  in sl;
    l1ina      :  in sl;
    --
    adcClk     :  in sl;
    adcRst     :  in sl;
    configA    :  in QuadAdcConfigType;
    trigIn     :  in slv         (ROW_SIZE-1 downto 0);
    adc        :  in AdcDataArray(NCHAN_G-1 downto 0);
    --
    dmaClk        :  in sl;
    dmaRst        :  in sl;
    eventHeader   :  in Slv192Array(NCHAN_G-1 downto 0);
    eventHeaderV  :  in slv        (NCHAN_G-1 downto 0);
    noPayload     :  in slv        (NCHAN_G-1 downto 0);
    eventHeaderRd : out slv        (NCHAN_G-1 downto 0);
    rstFifo       :  in sl;
--    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS      : out sl;
    dmaFullQ      : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    debug         : out slv(31 downto 0);
    dmaMaster     : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
    dmaSlave      : in  AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0) );
end QuadAdcEvent;

architecture mapping of QuadAdcEvent is

  constant NCHAN_C : integer := NCHAN_G;
  
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
  signal ql1in  : sl;
  signal ql1ina : sl;
  signal shift  : slv(31 downto 0);
  signal clear  : sl;
  signal start  : sl;
  
  signal iadc        : AdcDataArray(NCHAN_C-1 downto 0);

  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => ROW_SIZE*2,
    TDEST_BITS_C  => 4,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_FIXED_C,
    TUSER_BITS_C  => 2,
    TUSER_MODE_C  => TUSER_FIRST_LAST_C);

  signal chmasters   : AxiStreamMasterArray(NCHAN_C-1 downto 0);
  signal chslaves    : AxiStreamSlaveArray (NCHAN_C-1 downto 0);
  signal chafull     : slv(NCHAN_C-1 downto 0);
  signal chfull      : slv(NCHAN_C-1 downto 0);
  
  signal hdrValid  : slv(NCHAN_C-1 downto 0);
  signal hdrRd     : slv(NCHAN_C-1 downto 0);

  signal pllSync   : Slv32Array (NCHAN_C-1 downto 0);
  signal pllSyncV  : slv        (NCHAN_C-1 downto 0);
  signal eventHdr  : Slv256Array(NCHAN_C-1 downto 0);
  
  constant XPMV7 : boolean := false;

  signal r_state : slv(2 downto 0);
  signal r_syncstate : sl;
  signal r_intlv : sl;

  signal l1inacc, sl1inacc : sl;
  signal l1inrej, sl1inrej : sl;
  signal sl1in, sl1ina : sl;

  signal mAxilReadMasters  : AxiLiteReadMasterArray (NCHAN_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NCHAN_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NCHAN_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NCHAN_C-1 downto 0);
  
  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NCHAN_C-1 downto 0) := genAxiLiteConfig(NCHAN_C, BASE_ADDR_C, 15, 12);

  constant NSTREAMS_C : integer := FEX_ALGORITHMS(0)'length;
  constant NRAM_C     : integer := NCHAN_C * NSTREAMS_C;
  signal chBramWr : BRamWriteMasterArray(NRAM_C-1 downto 0);
  signal chBramRd : BRamReadMasterArray (NRAM_C-1 downto 0);
  signal chBRamSl : BRamReadSlaveArray  (NRAM_C-1 downto 0);
  
  constant DEBUG_C : boolean := false;

  component ila_0
    port ( clk   : in sl;
           probe0: in slv(255 downto 0) );
  end component;

  signal cacheStatus : CacheStatusArray(NCHAN_C-1 downto 0);
  signal chstreams   : Slv4Array       (NCHAN_C-1 downto 0);
  signal debugArray  : Slv32Array      (NCHAN_C-1 downto 0);

begin  -- mapping

  status <= cacheStatus(0);

  debug(0) <= start;
  debug(1) <= debugArray(0)(0);
  debug(31 downto 2) <= (others=>'0');
  
  GEN_DEBUG: if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk     => dmaClk,
                 probe0 ( 0 ) => dmaRst, 
                 probe0 ( 1 ) => start,
                 probe0 ( 2 ) => sl1in,
                 probe0 ( 3 ) => sl1ina,
                 probe0 ( 4 ) => chafull(0),                 
                 probe0 ( 5 ) => chfull(0),
                 probe0 ( 6 ) => chmasters(0).tValid,
                 probe0 ( 7 ) => chmasters(0).tLast,
                 probe0 (  9 downto  8 ) => chmasters(0).tUser( 1 downto 0),
                 probe0 ( 41 downto 10 ) => chmasters(0).tData(31 downto 0),
                 probe0 ( 42 ) => chslaves(0).tReady,
                 probe0 ( 255 downto 43 ) => (others=>'0') );
  end generate;

  dmaFullS  <= afull;
  dmaFullQ  <= (others=>'0');

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

  process ( eventClk ) is
  begin
    if rising_edge(eventClk) then
      l1inacc <= l1in and l1ina;
      l1inrej <= l1in and not l1ina;
    end if;
  end process;
  
  U_L1INACC : entity surf.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => l1inacc,
               dataOut => sl1inacc );
  
  U_L1INREJ : entity surf.SynchronizerOneShot
    port map ( clk      => dmaClk,
               dataIn   => l1inrej,
               dataOut  => sl1inrej );

  sl1in  <= sl1inacc or sl1inrej;
  sl1ina <= sl1inacc; 
           
  GEN_CH : for i in 0 to NCHAN_C-1 generate
    --
    --  If readout is in one stream, put the mask of channels in the header
    --
    GEN_ONE_HDR : if DMA_SIZE_G=1 generate
      eventHdr     (i) <= pllSync(i) &
                          configA.enable & toSlv(0,6) &
                          configA.samples(17 downto 4) & x"0" &
                          eventHeader(i);
    end generate;

    --
    --  If readout is in many streams, put the channel ID in the header
    --
    GEN_CHN_HDR : if DMA_SIZE_G>1 generate
      eventHdr     (i) <= pllSync(i) &
                          toSlv(i,8) & chstreams(i) & toSlv(0,2) &
                          configA.samples(17 downto 4) & x"0" &
                          eventHeader(i);
    end generate;
    
    hdrValid     (i) <= eventHeaderV(i) and (pllSyncV(i) or noPayload(i));
    eventHeaderRd(i) <= hdrRd(i);
    
    
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

--      This is the large buffer.
    GEN_RAM : for j in 0 to NSTREAMS_C-1 generate
      U_RAM : entity surf.SimpleDualPortRam
        generic map ( DATA_WIDTH_G => 16*ROW_SIZE,
                      ADDR_WIDTH_G => RAM_ADDR_WIDTH_C )
        port map ( clka   => dmaClk,
                   ena    => '1',
                   wea    => chBramWr(i*NSTREAMS_C+j).en,
                   addra  => chBramWr(i*NSTREAMS_C+j).addr,
                   dina   => chBramWr(i*NSTREAMS_C+j).data,
                   clkb   => dmaClk,
                   enb    => chBramRd(i*NSTREAMS_C+j).en,
                   rstb   => dmaRst,
                   addrb  => chBramRd(i*NSTREAMS_C+j).addr,
                   doutb  => chBramSl(i*NSTREAMS_C+j).data );
    end generate;
    
    U_FIFO : entity work.QuadAdcChannelFifo
      generic map ( BASE_ADDR_C => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    AXIS_CONFIG_G => CHN_AXIS_CONFIG_C,
                    ALGORITHM_G => FEX_ALGORITHMS(i),
--                    DEBUG_G     => ite(i>0, false, true) )
                    DEBUG_G     => false )
      port map ( clk      => dmaClk,
                 rst      => dmaRst,
                 clear    => clear,
                 start    => start,
                 shift    => shift(2 downto 0),
                 din      => adc(i),
                 l1in     => ql1in ,
                 l1ina    => ql1ina,
                 l1a      => open,
                 l1v      => open,
                 almost_full     => chafull  (i),
                 full            => chfull   (i),
                 status          => cacheStatus(i),
                 debug           => debugArray(i),
                 axisMaster      => chmasters(i),
                 axisSlave       => chslaves (i),
                 -- BRAM Interface (dmaClk domain)
                 bramWriteMaster => chBramWr((i+1)*NSTREAMS_C-1 downto i*NSTREAMS_C),
                 bramReadMaster  => chBramRd((i+1)*NSTREAMS_C-1 downto i*NSTREAMS_C),
                 bramReadSlave   => chBramSl((i+1)*NSTREAMS_C-1 downto i*NSTREAMS_C),
                 -- AXI-Lite Interface
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (i),
                 axilReadSlave   => mAxilReadSlaves  (i),
                 axilWriteMaster => mAxilWriteMasters(i),
                 axilWriteSlave  => mAxilWriteSlaves (i),
                 streams         => chstreams        (i) );

    GEN_DATA : if DMA_SIZE_G>1 generate
      U_DATA : entity work.QuadAdcChannelData
        generic map ( DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G )
        port map ( dmaClk      => dmaClk,
                   dmaRst      => dmaRst,
                   --
                   eventHdrV   => hdrValid (i),
                   eventHdr    => eventHdr (i),
                   noPayload   => noPayload(i),
                   eventHdrRd  => hdrRd    (i),
                   --
                   chnMaster   => chmasters(i),
                   chnSlave    => chslaves (i),
                   dmaMaster   => dmaMaster(i),
                   dmaSlave    => dmaSlave (i) );

    end generate GEN_DATA;
  end generate;

  GEN_ONE : if DMA_SIZE_G=1 generate
    U_DATA : entity work.QuadAdcChannelMux
      generic map ( NCHAN_C             => NCHAN_C,
                    DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G )
      port map ( dmaClk      => dmaClk,
                 dmaRst      => dmaRst,
                 --
                 eventHdrV   => hdrValid (0),
                 eventHdr    => eventHdr (0),
                 noPayload   => noPayload(0),
                 eventHdrRd  => hdrRd    (0),
                 --
                 chenable    => configA.enable(NCHAN_C-1 downto 0),
                 chmasters   => chmasters,
                 chslaves    => chslaves,
                 dmaMaster   => dmaMaster(0),
                 dmaSlave    => dmaSlave (0) );
    dmaMaster(dmaMaster'left downto 1) <= (others=>AXI_STREAM_MASTER_INIT_C);
  end generate;

  U_Trigger : entity work.QuadAdcTrigger
    generic map ( NCHAN_C => NCHAN_C )
    port map ( clk       => dmaClk,
               rst       => dmaRst,
               trigIn    => trigIn,  
               afullIn   => chafull,
               enable    => configA.acqEnable,
               l1in      => sl1in,
               l1ina     => sl1ina,
               --
               afullOut  => afull,
               ql1in     => ql1in,
               ql1ina    => ql1ina,
               shift     => shift,
               clear     => clear,
               start     => start );

end mapping;
