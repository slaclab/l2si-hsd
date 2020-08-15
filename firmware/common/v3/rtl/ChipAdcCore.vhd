-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ChipAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-08-11
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
use l2si_core.XpmExtensionPkg.all;

use work.FmcPkg.all;
use work.QuadAdcPkg.all;

entity ChipAdcCore is
  generic (
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C : slv(31 downto 0) := (others=>'0');
    DEBUG_G     : boolean := false );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    --
    triggerClk          : in  sl;
    triggerRst          : in  sl;
    triggerStrobe       : in  sl;
    triggerData         : in  TriggerEventDataType;
    enabled             : out sl;
    swtrig              : out sl;
    -- DMA
    dmaClk              : in  sl;
    dmaRst              : out sl;
    dmaRxIbMaster       : out AxiStreamMasterType;
    dmaRxIbSlave        : in  AxiStreamSlaveType;
    eventAxisMaster     : in  AxiStreamMasterType;
    eventAxisSlave      : out AxiStreamSlaveType;
    eventAxisCtrl       : out AxiStreamCtrlType;   --
    --
    fbPllRst            : out sl;
    fbPhyRst            : out sl;
    -- ADC
    adcClk              : in  sl;
    adcRst              : in  sl;
    adc                 : in  AdcDataArray(3 downto 0);
    adcValid            : in  sl;
    fmcClk              : in  sl );
end ChipAdcCore;

architecture mapping of ChipAdcCore is

  constant FIFO_ADDR_WIDTH_C : integer := 14;
  
  signal config               : QuadAdcConfigType;
  signal configA              : QuadAdcConfigType; -- adcClk domain
  signal vConfig, vConfigA    : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0);
  
  signal rstCount             : sl;

--  signal dmaFullThr, dmaFullThrS : slv(23 downto 0) := (others=>'0');
  signal dmaFullCnt           : slv(31 downto 0);
  signal dmaFull              : sl;  -- dmaClk domain
  
  signal idmaRst              : sl;
  signal dmaRstI              : slv(2 downto 0) := "000";
  signal dmaRstS              : sl;
  signal dmaStrobe            : sl;
  signal rstFifo              : sl;

  signal eventAxisSlaveTmp    : AxiStreamSlaveType;
  
  signal status               : QuadAdcStatusType;
  signal debug                : slv( 7 downto 0);

  constant NUM_AXI_MASTERS_C  : integer := 2;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) :=
    genAxiLiteConfig(NUM_AXI_MASTERS_C, BASE_ADDR_C, 13, 12);
  
  signal axilWriteMasters  : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal axilWriteSlaves   : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal axilReadMasters   : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal axilReadSlaves    : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  signal eventTrig          : sl;

  type CountRegType is record
    count : Slv32Array(2 downto 0);
  end record;

  constant COUNT_REG_INIT_C : CountRegType := ( count => (others=>(others=>'0')) );

  signal r_t, r_d : CountRegType;
  signal rin_t, rin_d : CountRegType := COUNT_REG_INIT_C;

  signal rstCountSyncT, rstCountSyncD : sl;
  
begin  

  dmaRst             <= dmaRstS;
  eventAxisSlave     <= eventAxisSlaveTmp;
  enabled            <= configA.acqEnable;
  
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
      mAxiWriteMasters => axilWriteMasters,
      mAxiWriteSlaves  => axilWriteSlaves,
      mAxiReadMasters  => axilReadMasters,
      mAxiReadSlaves   => axilReadSlaves);
  
  U_EventDma : entity work.ChipAdcEvent
    generic map ( FIFO_ADDR_WIDTH_C   => FIFO_ADDR_WIDTH_C,
                  DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G,
                  BASE_ADDR_C         => AXI_CROSSBAR_MASTERS_CONFIG_C(1).baseAddr,
                  DEBUG_G             => DEBUG_G )
    port map (    axilClk         => axiClk,
                  axilRst         => axiRst,
                  axilReadMaster  => axilReadMasters (1),
                  axilReadSlave   => axilReadSlaves  (1),
                  axilWriteMaster => axilWriteMasters(1),
                  axilWriteSlave  => axilWriteSlaves (1),
                  --
                  adcClk     => adcClk,
                  adcRst     => adcRst,
                  configA    => configA,
                  adc        => adc,
                  adcValid   => adcValid,
                  --
                  triggerClk    => triggerClk,
                  triggerRst    => triggerRst,
                  triggerData   => triggerData,
                  --
                  dmaClk          => dmaClk,
                  dmaRst          => dmaRstS,
                  eventAxisMaster => eventAxisMaster,
                  eventAxisSlave  => eventAxisSlaveTmp,
                  eventAxisCtrl   => eventAxisCtrl,
                  eventTrig       => eventTrig,
                  --
                  dmaFullS   => dmaFull,
                  dmaFullCnt => dmaFullCnt,
                  dmaMaster  => dmaRxIbMaster,
                  dmaSlave   => dmaRxIbSlave ,
                  status     => status.eventCache,
                  buildstatus=> status.build,
                  debug      => debug );

  U_DSReg : entity work.ChipAdcReg
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => axilWriteMasters(0),
                  axilWriteSlave      => axilWriteSlaves (0),
                  axilReadMaster      => axilReadMasters (0),
                  axilReadSlave       => axilReadSlaves  (0),
                  -- configuration
                  irqEnable           => open      ,
                  config              => config    ,
                  adcSyncRst          => swtrig    ,
                  dmaRst              => idmaRst   ,
                  fbRst               => fbPhyRst  ,
                  fbPLLRst            => fbPllRst  ,
                  -- status
                  irqReq              => '0'       ,
                  rstCount            => rstCount  ,
                  dmaClk              => dmaClk    ,
                  status              => status    );

  -- Synchronize configurations to adcClk
  vConfig <= toSlv       (config);
  configA <= toQadcConfig(vConfigA);

  U_ConfigA : entity surf.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => adcClk,
                  rst     => adcRst,
                  dataIn  => vConfig,
                  dataOut => vConfigA );

  Sync_dmaCtrlCount : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => 32 )
    port map    ( wr_clk       => dmaClk,
                  din          => dmaFullCnt,
                  rd_clk       => axiClk,
                  dout         => status.dmaCtrlCount );

  --
  --  Synchronize reset to timing strobe to fix phase for gearbox
  --
  Sync_dmaStrobe : entity surf.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => triggerStrobe,
               dataOut => dmaStrobe );

  Sync_dmaRst : process (dmaClk) is
  begin
    if rising_edge(dmaClk) then
      dmaRstI <= dmaRstI(dmaRstI'left-1 downto 0) & dmaRstI(0);
      if idmaRst='1' then
        dmaRstI(0) <= '1';
      elsif dmaStrobe='1' then
        dmaRstI(0) <= '0';
      end if;
    end if;
  end process;

  U_DMARST : BUFG
    port map ( O => dmaRstS,
               I => dmaRstI(2) );

  Sync_RstCountT  : entity surf.RstSync
    port map ( clk      => triggerClk,
               asyncRst => rstCount,
               syncRst  => rstCountSyncT );
  
  Sync_RstCountD  : entity surf.RstSync
    port map ( clk      => dmaClk,
               asyncRst => rstCount,
               syncRst  => rstCountSyncD );
  
  comb_t : process(triggerRst, rstCountSyncT, r_t, triggerStrobe, triggerData, eventAxisSlaveTmp, eventAxisMaster) is
    variable v : CountRegType;
  begin
    v := r_t;

    if triggerStrobe = '1' then
      v.count(0) := r_t.count(0) + 1;
    end if;

    if triggerData.valid = '1' and triggerData.l0Accept = '1' then
      v.count(1) := r_t.count(1) + 1;
    end if;

    if eventAxisMaster.tValid = '1' and eventAxisSlaveTmp.tReady = '1' then
      v.count(2) := r_t.count(2) + 1;
    end if;

    if triggerRst = '1' or rstCountSyncT = '1' then
      v := COUNT_REG_INIT_C;
    end if;

    rin_t <= v;
  end process comb_t;

  seq_t : process(triggerClk) is
  begin
    if rising_edge(triggerClk) then
      r_t <= rin_t;
    end if;
  end process seq_t;

  GEN_SYNC_COUNT : for i in 0 to 2 generate
    U_SyncCount : entity surf.SynchronizerFifo
      generic map ( DATA_WIDTH_G => 32 )
      port map ( rst    => axiRst,
                 wr_clk => triggerClk,
                 din    => r_t.count(i),
                 rd_clk => axiClk,
                 dout   => status.eventCount(i) );
  end generate;
  
  comb_d : process(dmaRstS, rstCountSyncD, r_d, eventTrig) is
    variable v : CountRegType;
  begin
    v := r_d;

    if eventTrig = '1' then
      v.count(0) := r_d.count(0) + 1;
    end if;

    if dmaRstS = '1' or rstCountSyncD = '1' then
      v := COUNT_REG_INIT_C;
    end if;

    rin_d <= v;
  end process comb_d;

  U_SyncTrigCount : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => 32 )
    port map ( rst    => axiRst,
               wr_clk => dmaClk,
               din    => r_d.count(0),
               rd_clk => axiClk,
               dout   => status.eventCount(3) );
               
  
end mapping;
