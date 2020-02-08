-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ChipAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-02-07
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

library l2si_core;
use l2si_core.L2SiPkg.all;

--use lcls_timing_core.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.FexAlgPkg.all;
use work.FmcPkg.all;

entity ChipAdcEvent is
  generic (
    FIFO_ADDR_WIDTH_C : integer := 10;
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
    adcClk          :  in sl;
    adcRst          :  in sl;
    configA         :  in QuadAdcConfigType;
    trigIn          :  in slv         (ROW_SIZE-1 downto 0);
    adc             :  in AdcDataArray(3 downto 0);
    adcValid        :  in sl; 
    --
    triggerClk      :  in sl;
    triggerData     :  in TriggerEventDataType;
    --
    dmaClk          :  in sl;
    dmaRst          :  in sl;
    eventAxisMaster :  in AxiStreamMasterType;
    eventAxisSlave  : out AxiStreamSlaveType;
    eventAxisCtrl   : out AxiStreamCtrlType;   --
--    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS        : out sl;
    dmaFullCnt      : out slv(31 downto 0);
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    debug           : out slv(7 downto 0);
    dmaMaster       : out AxiStreamMasterType;
    dmaSlave        : in  AxiStreamSlaveType );
end ChipAdcEvent;

architecture mapping of ChipAdcEvent is

  constant NCHAN_C : integer := 4;
  
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
  signal shiftTmp : slv(31 downto 0);
  signal shift  : slv(31 downto 0);
  signal start  : sl;
  signal clear : sl;

  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  
  -- interleave payload
  signal iadc        : AdcWordArray(4*ROW_SIZE-1 downto 0);
  signal ilvmasters  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
  signal ilvslaves   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
  signal ilvafull    : sl;
  signal ilvoflow    : sl;

  signal hdrValid  : sl;
  signal hdrRd     : sl;
  
  signal pllSync   : slv(31 downto 0);
  signal pllSyncV  : sl;
  signal eventHdr  : slv(255 downto 0);

  signal l1inacc, sl1inacc : sl;
  signal l1inrej, sl1inrej : sl;
  signal sl1in, sl1ina : sl;
  signal noPayload : sl;
 
  constant APPLY_SHIFT_C : boolean := false;

  constant NSTREAMS_C : integer := FEX_ALGORITHMS'length;
  constant NRAM_C     : integer := 4 * NSTREAMS_C;
  signal bramWr    : BRamWriteMasterArray(NRAM_C-1 downto 0);
  signal bramRd    : BRamReadMasterArray (NRAM_C-1 downto 0);
  signal bRamSl    : BRamReadSlaveArray  (NRAM_C-1 downto 0);

  signal cacheStatus : CacheArray(MAX_OVL_C-1 downto 0);

begin  -- mapping

  status     <= cacheStatus;
  dmaFullS   <= afull;
  dmaFullCnt <= afullCnt;

  process ( triggerClk ) is
  begin
    if rising_edge(triggerClk) then
      l1inacc <= triggerData.valid and triggerData.l1Expect and     triggerData.l1Accept;
      l1inrej <= triggerData.valid and triggerData.l1Expect and not triggerData.l1Accept;
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
  
--      This is the large buffer.
  GEN_RAM : for j in 0 to NSTREAMS_C-1 generate
    GEN_CHAN : for k in 0 to 3 generate
      U_RAM : entity surf.SimpleDualPortRam
        generic map ( DATA_WIDTH_G => 16*ROW_SIZE,   -- 64*ROW_SIZE? or 4x RAMs
                      ADDR_WIDTH_G => RAM_ADDR_WIDTH_C )
        port map ( clka   => dmaClk,
                   ena    => '1',
                   wea    => bramWr(k+4*j).en,
                   addra  => bramWr(k+4*j).addr,
                   dina   => bramWr(k+4*j).data,
                   clkb   => dmaClk,
                   enb    => bramRd(k+4*j).en,
                   rstb   => dmaRst,
                   addrb  => bramRd(k+4*j).addr,
                   doutb  => bramSl(k+4*j).data );
    end generate;
  end generate;

  --  overwrite header bytes 24-31
  noPayload             <= eventAxisMaster.tDest(0);
  eventHdr              <= pllSync &
                           toSlv(1,8) & toSlv(0,4) &
                           configA.samples(17 downto 4) & toSlv(0,6) &
                           eventAxisMaster.tData(191 downto 0);
  hdrValid              <= eventAxisMaster.tValid and (pllSyncV or noPayload);
  eventAxisSlave.tReady <= hdrRd;
  eventAxisCtrl.pause   <= afull;
  eventAxisCtrl.overflow<= ilvoflow;
  eventAxisCtrl.idle    <= '0';

  --  interleave --
  GEN_ROW : for j in 0 to ROW_SIZE-1 generate
    GEN_COL : for k in 0 to 3 generate
      iadc         (4*j+k) <= adc(k).data(j);
    end generate;
  end generate;
  
  U_PllSyncF : entity surf.FifoSync
    generic map ( ADDR_WIDTH_G => 4,
                  DATA_WIDTH_G => 32,
                  FWFT_EN_G    => true )
    port map ( rst    => dmaRst,
               clk    => dmaClk,
               wr_en  => start,
               din    => shift,
               rd_en  => hdrRd   ,
               dout   => pllSync ,
               valid  => pllSyncV );

  U_INTLV : entity work.QuadAdcInterleavePacked
    generic map ( BASE_ADDR_C    => BASE_ADDR_C,
                  AXIS_CONFIG_G  => CHN_AXIS_CONFIG_C,
                  ALGORITHM_G    => FEX_ALGORITHMS,
                  DEBUG_G        => false )
    port map ( clk             => dmaClk,
               rst             => dmaRst,
               clear           => clear,
               start           => start,
               shift           => shift(3 downto 0),
               din             => iadc          ,
               l1in            => ql1in,
               l1ina           => ql1ina,
               l1a             => open,
               l1v             => open,
               almost_full     => ilvafull      ,
               overflow        => ilvoflow      ,
               status          => cacheStatus   ,
               debug           => debug         ,
               axisMaster      => ilvmasters    ,
               axisSlave       => ilvslaves     ,
               -- BRAM Interface (dmaClk domain)
               bramWriteMaster => bramWr(4*NSTREAMS_C-1 downto 0),
               bramReadMaster  => bramRd(4*NSTREAMS_C-1 downto 0),
               bramReadSlave   => bramSl(4*NSTREAMS_C-1 downto 0),
               -- AXI-Lite Interface
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMaster,
               axilReadSlave   => axilReadSlave ,
               axilWriteMaster => axilWriteMaster,
               axilWriteSlave  => axilWriteSlave );

  U_DATA : entity work.QuadAdcChannelData
    generic map ( SAXIS_CONFIG_G => CHN_AXIS_CONFIG_C,
                  MAXIS_CONFIG_G => DMA_STREAM_CONFIG_G,
                  DEBUG_G        => false )
    port map ( dmaClk      => dmaClk,
               dmaRst      => dmaRst,
               --
               eventHdrV   => hdrValid ,
               eventHdr    => eventHdr ,
               noPayload   => noPayload,
               eventHdrRd  => hdrRd    ,
               --
               chnMaster   => ilvmasters,
               chnSlave    => ilvslaves ,
               dmaMaster   => dmaMaster,
               dmaSlave    => dmaSlave  );

  U_Trigger : entity work.QuadAdcTrigger
    generic map ( NCHAN_C => 1 )
    port map ( clk       => dmaClk,
               rst       => dmaRst,
               trigIn    => trigIn,  
               afullIn(0)=> ilvafull,
               enable (0)=> configA.acqEnable,
               l1in      => sl1in,
               l1ina     => sl1ina,
               --
               afullOut  => afull,
               afullCnt  => afullCnt,
               ql1in     => ql1in,
               ql1ina    => ql1ina,
               shift     => shiftTmp,
               clear     => clear,
               start     => start );

  shift <= adcValid & shiftTmp(30 downto 0);

end mapping;
