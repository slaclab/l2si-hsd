-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DualAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2021-05-18
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
use surf.SsiPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmPkg.all;

use work.FmcPkg.all;
use work.QuadAdcPkg.all;

entity DualAdcCore is
  generic (
    TPD_G       : time    := 1 ns;
    LCLSII_G    : boolean := TRUE; -- obsolete
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C : slv(31 downto 0) := (others=>'0') );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- DMA
    dmaClk              : in  sl;
    dmaRst              : out slv                 (1 downto 0);
    dmaRxIbMaster       : out AxiStreamMasterArray(1 downto 0);
    dmaRxIbSlave        : in  AxiStreamSlaveArray (1 downto 0);
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
    adc                 : in  AdcDataArray(7 downto 0);
    adcValid            : in  slv(1 downto 0);
    fmcClk              : in  slv(1 downto 0);
    --
    trigSlot            : out slv(1 downto 0) );
end DualAdcCore;

architecture mapping of DualAdcCore is

  constant NFMC_C            : integer := 2;
  
  signal ifbPllRst            : slv       (NFMC_C-1 downto 0);
  signal ifbPhyRst            : slv       (NFMC_C-1 downto 0);
  signal localId              : Slv32Array(NFMC_C-1 downto 0);

  signal msgDelaySet          : Slv7Array (XPM_PARTITIONS_C-1 downto 0);

  signal phaseValue : Slv16Array(3 downto 0);
  signal phaseCount : Slv16Array(3 downto 0);
  
  -- one bus per chip ctrl (2), one bus per fex stream (2*3?)
  constant NUM_AXI_MASTERS_C : integer := 3;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(2 downto 0) :=
    genAxiLiteConfig(3, BASE_ADDR_C, 15, 13);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  signal triggerData : TriggerEventDataArray(NFMC_C-1 downto 0);
  signal eventAxisMasters    : AxiStreamMasterArray(NFMC_C-1 downto 0);
  signal eventAxisSlaves     : AxiStreamSlaveArray (NFMC_C-1 downto 0);
  signal eventAxisCtrl       : AxiStreamCtrlArray  (NFMC_C-1 downto 0);

begin  

  --------------------------
  -- AXI-Lite: Crossbar Core
  --------------------------
  U_XBAR : entity surf.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => axiClk,
      axiClkRst        => axiRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves (0) => axilWriteSlave,
      sAxiReadMasters (0) => axilReadMaster,
      sAxiReadSlaves  (0) => axilReadSlave,
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

  U_TriggerEventManager : entity l2si_core.TriggerEventManager
    generic map (
      NUM_DETECTORS_G                => NFMC_C,
      TRIGGER_CLK_IS_TIMING_RX_CLK_G => true,
      AXIL_BASE_ADDR_G               => AXI_CROSSBAR_MASTERS_CONFIG_C(2).baseAddr )
    port map (
      timingRxClk => evrClk,
      timingRxRst => evrRst,
      timingBus   => evrBus,
      timingMode  => evrBus.modesel,
      
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

      -- AXI-Lite
      axilClk         => axiClk,
      axilRst         => axiRst,
      axilReadMaster  => mAxilReadMasters (2),
      axilReadSlave   => mAxilReadSlaves  (2),
      axilWriteMaster => mAxilWriteMasters(2),
      axilWriteSlave  => mAxilWriteSlaves (2) );

  GEN_FMC : for i in 0 to NFMC_C-1 generate

    trigSlot(i) <= triggerData(i).valid;
    
    U_ChipAdcCore : entity work.ChipAdcCore
      generic map ( DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G,
                    BASE_ADDR_C         => AXI_CROSSBAR_MASTERS_CONFIG_C(i).baseAddr,
                    DEBUG_G             => (i=0) )
      port map ( axiClk              => axiClk,
                 axiRst              => axiRst,
                 axilWriteMaster     => mAxilWriteMasters(i),
                 axilWriteSlave      => mAxilWriteSlaves (i),
                 axilReadMaster      => mAxilReadMasters (i),
                 axilReadSlave       => mAxilReadSlaves  (i),
                 --
                 triggerClk          => evrClk,
                 triggerRst          => evrRst,
                 triggerStrobe       => evrBus.strobe,
                 triggerData         => triggerData  (i),
                 -- DMA
                 dmaClk              => dmaClk,
                 dmaRst              => dmaRst       (i),
                 dmaRxIbMaster       => dmaRxIbMaster(i),
                 dmaRxIbSlave        => dmaRxIbSlave (i),
                 eventAxisMaster     => eventAxisMasters   (i),
                 eventAxisSlave      => eventAxisSlaves    (i),
                 eventAxisCtrl       => eventAxisCtrl      (i),
                 --
                 fbPllRst            => ifbPllRst    (i),
                 fbPhyRst            => ifbPhyRst    (i),
                 -- ADC
                 adcClk              => adcClk,
                 adcRst              => adcRst,
                 adc                 => adc          (4*i+3 downto 4*i),
                 adcValid            => adcValid     (i),
                 fmcClk              => fmcClk       (i) );
  end generate;
  
end mapping;
