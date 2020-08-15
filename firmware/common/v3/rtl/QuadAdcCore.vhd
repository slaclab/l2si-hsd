-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

library unisim;
use unisim.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

use surf.SsiPkg.all;

use work.FmcPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcCore is
  generic (
    TPD_G       : time    := 1 ns;
    LCLSII_G    : boolean := TRUE; -- obsolete
    NFMC_G      : integer := 1;
    SYNC_BITS_G : integer := 4;
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    DMA_SIZE_G  : integer := 1;
    BASE_ADDR_C : Slv32Array(2 downto 0) := (others=>x"00000000") );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMasters    : in  AxiLiteWriteMasterArray(2 downto 0);
    axilWriteSlaves     : out AxiLiteWriteSlaveArray (2 downto 0);
    axilReadMasters     : in  AxiLiteReadMasterArray (2 downto 0);
    axilReadSlaves      : out AxiLiteReadSlaveArray  (2 downto 0);
    -- DMA
    dmaClk              : in  sl;
    dmaRst              : out slv                 (NFMC_G-1 downto 0);
    dmaRxIbMaster       : out AxiStreamMasterArray(NFMC_G-1 downto 0);
    dmaRxIbSlave        : in  AxiStreamSlaveArray (NFMC_G-1 downto 0);
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
--    ready               : out sl;
    timingFbClk         : in  sl;
    timingFbRst         : in  sl;
    timingFb            : out TimingPhyType;
    -- ADC
    gbClk               : in  sl;
    adcClk              : in  sl;
    adcRst              : in  sl;
    adc                 : in  AdcDataArray(4*NFMC_G-1 downto 0);
    fmcClk              : in  slv(NFMC_G-1 downto 0);
    --
    trigSlot            : out sl;
    trigOut             : out sl;
    trigIn              : in  slv(ROW_SIZE-1 downto 0);
    adcSyncRst          : out sl;
    adcSyncLocked       : in  sl );
end QuadAdcCore;

architecture mapping of QuadAdcCore is

  type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  constant FIFO_ADDR_WIDTH_C : integer := 14;
  constant NCHAN_C           : integer := 4*NFMC_G;

  signal paddr               : slv(31 downto 0);
  signal config              : QuadAdcConfigType;
  signal configE             : QuadAdcConfigType; -- evrClk domain
  signal configA             : QuadAdcConfigType; -- adcClk domain
  signal configF             : QuadAdcConfigType; -- timingFbClk domain
  signal vConfig, vConfigE, vConfigA, vConfigF   : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0);
  
  signal oneHz               : sl := '0';
  
  signal eventSel            : slv      (NFMC_G-1 downto 0);
  signal eventSelQ           : slv      (NFMC_G-1 downto 0);
  signal rstCount            : sl;

  signal irqRequest          : sl;

  signal dmaFifoDepth        : slv( 9 downto 0);

  signal dmaFull             : sl;  -- dmaClk domain
  
  signal idmaRst             : slv      (1 downto 0);
  signal dmaRstI             : Slv3Array(NFMC_G-1 downto 0) := (others=>(others=>'1'));
  signal dmaRstS             : slv      (NFMC_G-1 downto 0);
  signal dmaStrobe           : sl;

  signal triggerData          : TriggerEventDataArray(NFMC_G-1 downto 0);
  signal eventAxisMasters    : AxiStreamMasterArray(NFMC_G-1 downto 0);
  signal eventAxisSlaves     : AxiStreamSlaveArray (NFMC_G-1 downto 0);
  signal eventAxisCtrl       : AxiStreamCtrlArray  (NFMC_G-1 downto 0);

  signal eventHdrD            : Slv192Array     (NFMC_G-1 downto 0);
  signal eventHdrV            : slv             (NFMC_G-1 downto 0);
  signal eventHdrRd           : slv             (NFMC_G-1 downto 0);
  signal pmsg                 : slv             (NFMC_G-1 downto 0);
  signal rstFifo              : slv             (NFMC_G-1 downto 0);
  signal status_eventCount    : SlVectorArray(4 downto 0,31 downto 0);
  
  signal phaseValue : Slv16Array(3 downto 0);
  signal phaseCount : Slv16Array(3 downto 0);
  
  signal status : QuadAdcStatusType;
  signal axisMaster : AxiStreamMasterArray(NFMC_G-1 downto 0);
  signal axisSlave  : AxiStreamSlaveArray (NFMC_G-1 downto 0);

  signal debug      : Slv8Array           (NFMC_G-1 downto 0);
  signal debugS     : Slv8Array           (NFMC_G-1 downto 0);
  signal debugSV    : slv                 (NFMC_G-1 downto 0);

begin  

--  dmaRst        <= idmaRst;
  dmaRst        <= dmaRstS;
  dmaRxIbMaster <= axisMaster;
  axisSlave     <= dmaRxIbSlave;

  U_TEM : entity l2si_core.TriggerEventManager
    generic map ( EN_LCLS_I_TIMING_G             => not LCLSII_G,
                  EN_LCLS_II_TIMING_G            => LCLSII_G,
                  NUM_DETECTORS_G                => NFMC_G,
                  TRIGGER_CLK_IS_TIMING_RX_CLK_G => true,
                  AXIL_BASE_ADDR_G               => BASE_ADDR_C(2) )
    port map (
      timingRxClk => evrClk,
      timingRxRst => evrRst,
      timingBus   => evrBus,
      timingMode  => ite(LCLSII_G,'1','0'),

      -- Timing Tx Feedback
      timingTxClk => timingFbClk,
      timingTxRst => timingFbRst,
      timingTxPhy => timingFb,

      -- Triggers 
      triggerClk  => evrClk,
      triggerRst  => evrRst,
      triggerData => triggerData,

      -- Output Streams
      eventClk            => dmaClk,
      eventRst            => adcRst,
      eventTimingMessages => open,
      eventAxisMasters    => eventAxisMasters,
      eventAxisSlaves     => eventAxisSlaves,
      eventAxisCtrl       => eventAxisCtrl,
      clearReadout        => rstFifo,
      
      -- AXI-Lite
      axilClk         => axiClk,
      axilRst         => axiRst,
      axilReadMaster  => axilReadMasters (2),
      axilReadSlave   => axilReadSlaves  (2),
      axilWriteMaster => axilWriteMasters(2),
      axilWriteSlave  => axilWriteSlaves (2) );
          
  GEN_FMC : for i in 0 to NFMC_G-1 generate
    eventSel       (i) <= triggerData(i).l0Accept and triggerData(i).valid;
    eventSelQ      (i) <= eventSel(i) and not configE.inhibit;
    eventHdrD      (i) <= eventAxisMasters(i).tData(191 downto 0);
    eventHdrV      (i) <= eventAxisMasters(i).tValid;
    pmsg           (i) <= eventAxisMasters(i).tDest(0);
    
    eventAxisSlaves(i).tReady   <= eventHdrRd(i);
    eventAxisCtrl  (i).pause    <= dmaFull; -- full signal shared
    eventAxisCtrl  (i).overflow <= '0';
    eventAxisCtrl  (i).idle     <= '0';
  end generate;
  
  trigSlot     <= triggerData(0).valid;
  trigOut      <= eventSelQ  (0);

  U_EventDma : entity work.QuadAdcEvent
    generic map ( TPD_G               => TPD_G,
                  FIFO_ADDR_WIDTH_C   => FIFO_ADDR_WIDTH_C,
                  NFMC_G              => NFMC_G,
                  SYNC_BITS_G         => SYNC_BITS_G,
                  DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G,
                  BASE_ADDR_C         => BASE_ADDR_C(1) )
    port map (    axilClk         => axiClk,
                  axilRst         => axiRst,
                  axilReadMaster  => axilReadMasters (1),
                  axilReadSlave   => axilReadSlaves  (1),
                  axilWriteMaster => axilWriteMasters(1),
                  axilWriteSlave  => axilWriteSlaves (1),
                  --
                  eventClk    => evrClk,
                  trigArm     => eventSelQ(0),
                  triggerData => triggerData(0),
                  --
                  adcClk     => adcClk,
                  adcRst     => adcRst,
                  configA    => configA,
                  adc        => adc,
                  trigIn     => trigIn,
                  --
                  dmaClk     => dmaClk,
                  dmaRst     => dmaRstS(0),
                  eventHeader   => eventHdrD,
                  eventHeaderV  => eventHdrV,
                  noPayload     => pmsg,
                  eventHeaderRd => eventHdrRd,
                  rstFifo    => rstFifo(0),
                  dmaFullS   => dmaFull,
                  dmaMaster  => axisMaster,
                  dmaSlave   => axisSlave ,
                  status     => status.eventCache(0),
                  debug      => debug );

  Sync_EvtCount : entity surf.SyncStatusVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => 5 )
    port map    ( statusIn(4)  => '0',
                  statusIn(3)  => '0',
                  statusIn(2)  => eventHdrRd(0),
                  statusIn(1)  => evrBus.strobe,
                  statusIn(0)  => eventSel(0),
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => status_eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

  GEN_EVENTCOUNT : for i in 4 downto 0 generate
    status.eventCount(i) <= muxSlVectorArray(status_eventCount,i);
  end generate;
  
  U_DSReg : entity work.DSReg
    generic map ( TPD_G               => TPD_G )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => axilWriteMasters(0),
                  axilWriteSlave      => axilWriteSlaves (0),
                  axilReadMaster      => axilReadMasters (0),
                  axilReadSlave       => axilReadSlaves  (0),
                  -- configuration
                  irqEnable           => open      ,
                  config              => config    ,
                  adcSyncRst          => adcSyncRst,
                  fmcRst              => idmaRst   ,
                  --fbRst               => fbPhyRst  ,
                  --fbPLLRst            => fbPllRst  ,
                  -- status
                  irqReq              => irqRequest   ,
                  rstCount            => rstCount     ,
                  dmaClk              => dmaClk,
                  status              => status );

  -- Synchronize configurations to evrClk
  vConfig <= toSlv       (config);
  configE <= toQadcConfig(vConfigE);
  configA <= toQadcConfig(vConfigA);
  U_ConfigE : entity surf.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => evrClk,
                  rst     => evrRst,
                  dataIn  => vConfig,
                  dataOut => vConfigE );
  U_ConfigA : entity surf.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => adcClk,
                  rst     => adcRst,
                  dataIn  => vConfig,
                  dataOut => vConfigA );

  --
  --  Synchronize reset to timing strobe to fix phase for gearbox
  --
  Sync_dmaStrobe : entity surf.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => evrBus.strobe,
               dataOut => dmaStrobe );

  Sync_dmaRst : process (dmaClk) is
  begin
    if rising_edge(dmaClk) then
      for i in 0 to NFMC_G-1 loop
        dmaRstI(i) <= dmaRstI(i)(1 downto 0) & dmaRstI(i)(0);
        if idmaRst(i)='1' then
          dmaRstI(i)(0) <= '1';
        elsif dmaStrobe='1' then
          dmaRstI(i)(0) <= '0';
        end if;
      end loop;
    end if;
  end process;

  GEN_RSTBUF : for i in 0 to NFMC_G-1 generate
    U_DMARST : BUFG
      port map ( O => dmaRstS(i),
                 I => dmaRstI(i)(2) );
  end generate;
  
  U_ADC_PHASE : entity work.PhaseDetector
    generic map ( WIDTH_G => 16 )
    port map ( stableClk  => axiClk,
               latch      => '0',
               refClk     => adcClk,
               refClkRst  => adcRst,
               testClk    => evrClk,
               testClkRst => evrRst,
               testSync   => evrBus.strobe,
               testId     => evrBus.message.pulseId(0),
               ready      => open,
               phase0     => phaseValue(0),
               phase1     => phaseValue(1),
               count0     => phaseCount(0),
               count1     => phaseCount(1),
               valid      => open );

  U_TREE_PHASE : entity work.PhaseDetector
    generic map ( WIDTH_G => 16 )
    port map ( stableClk  => axiClk,
               latch      => '0',
               refClk     => fmcClk(0),
               refClkRst  => adcRst,
               testClk    => evrClk,
               testClkRst => evrRst,
               testSync   => evrBus.strobe,
               testId     => evrBus.message.pulseId(0),
               ready      => open,
               phase0     => phaseValue(2),
               phase1     => phaseValue(3),
               count0     => phaseCount(2),
               count1     => phaseCount(3),
               valid      => open );
  
  comb : process ( axiRst, r,
                   phaseValue, phaseCount, 
                   axilWriteMasters(2), axilReadMasters(2) ) is
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn( ep,
                     axilWriteMasters(2), axilReadMasters(2),
                     v.axilWriteSlave, v.axilReadSlave );

    for i in 0 to 3 loop
      axiSlaveRegisterR( ep, toSlv(32+4*i,8), 0, phaseValue(i) );
      axiSlaveRegisterR( ep, toSlv(48+4*i,8), 0, phaseCount(i) );
    end loop;
                
    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    axilWriteSlaves(2) <= r.axilWriteSlave;
    axilReadSlaves (2) <= r.axilReadSlave;

    if axiRst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  aseq : process ( axiClk ) is
  begin
    if rising_edge(axiClk) then
      r <= r_in;
    end if;
  end process aseq;
  
end mapping;
