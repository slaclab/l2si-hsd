-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2019-08-31
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
use lcls_timing_core.TimingExtnPkg.all;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.EventPkg.all;
use surf.SsiPkg.all;
use l2si_core.XpmPkg.all;
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
    BASE_ADDR_C : slv(31 downto 0) := (others=>'0') );
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
    exptBus             : in  ExptBusType;
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

  signal histMaster          : AxiStreamMasterType;
  signal histSlave           : AxiStreamSlaveType;
  
  signal irqRequest          : sl;

  signal dmaFifoDepth        : slv( 9 downto 0);

--  signal dmaFullThr, dmaFullThrS : slv(23 downto 0) := (others=>'0');
  signal dmaFullCnt          : slv(31 downto 0);
  signal dmaFull             : sl;  -- dmaClk domain
  signal dmaFullS            : sl;  -- evrClk domain
  signal dmaFullSS           : sl;  -- timingFbClk domain
  signal dmaFullV            : slv(NPartitions-1 downto 0);
  
  signal idmaRst             : slv      (1 downto 0);
  signal dmaRstI             : Slv3Array(NFMC_G-1 downto 0) := (others=>(others=>'1'));
  signal dmaRstS             : slv      (NFMC_G-1 downto 0);
  signal dmaStrobe           : sl;

  signal l1in, l1ina         : sl;

  constant HIST_STREAM_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 4,
    TDEST_BITS_C  => 0,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_NORMAL_C,
    TUSER_BITS_C  => 0,
    TUSER_MODE_C  => TUSER_NONE_C );

  signal timingHeader_prompt  : TimingHeaderType;
  signal timingHeader_aligned : TimingHeaderType;
  signal exptBus_aligned      : ExptBusType;
  signal trigData             : XpmPartitionDataArray(NFMC_G-1 downto 0);
  signal trigDataV            : slv             (NFMC_G-1 downto 0);
  signal eventHdr             : EventHeaderArray(NFMC_G-1 downto 0);
  signal eventHdrD            : Slv192Array     (NFMC_G-1 downto 0);
  signal eventHdrV            : slv             (NFMC_G-1 downto 0);
  signal eventHdrRd           : slv             (NFMC_G-1 downto 0);
  signal phdr                 : slv             (NFMC_G-1 downto 0);
  signal pmsg                 : slv             (NFMC_G-1 downto 0);
  signal rstFifo              : slv             (NFMC_G-1 downto 0);
  signal wrFifoCnt            : Slv4Array       (NFMC_G-1 downto 0);
  signal rdFifoCnt            : Slv4Array       (NFMC_G-1 downto 0);
  signal fbPllRst             : sl;
  signal fbPhyRst             : sl;

  signal msgDelaySet          : Slv7Array (NPartitions-1 downto 0);
  signal msgDelayGet          : Slv7Array (NFMC_G-1 downto 0);
  signal cntL0                : Slv20Array(NFMC_G-1 downto 0);
  signal cntOflow             : Slv8Array (NFMC_G-1 downto 0);

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

  --U_FbReset : entity surf.RstSync
  --  port map ( clk      => timingFbClk,
  --             asyncRst => fbPhyRst,
  --             syncRst  => fbReset );

  U_TimingFb : entity l2si_core.XpmTimingFb
    generic map ( DEBUG_G => true )
    port map ( clk        => timingFbClk,
               rst        => timingFbRst,
               pllReset   => fbPllRst,
               phyReset   => fbPhyRst,
               id         => hsdTimingFbId(config.localId),
               l1input    => (others=>XPM_L1_INPUT_INIT_C),
               full       => dmaFullV,
               phy        => timingFb );

  timingHeader_prompt.strobe    <= evrBus.strobe;
  timingHeader_prompt.pulseId   <= evrBus.message.pulseId;
  timingHeader_prompt.timeStamp <= evrBus.message.timeStamp;
  U_Realign  : entity l2si_core.EventRealign
    port map ( rst           => evrRst,
               clk           => evrClk,
               timingI       => timingHeader_prompt,
               exptBusI      => exptBus,
               timingO       => timingHeader_aligned,
               exptBusO      => exptBus_aligned,
               delay         => msgDelaySet );
  
  status.msgDelaySet <= msgDelaySet(conv_integer(configE.partition(0)));
  
  --dmaHistDump <= oneHz and dmaHistEnaS;

  --Sync_dmaHistDump : entity surf.SynchronizerOneShot
  --  port map ( clk     => dmaClk,
  --             dataIn  => dmaHistDump,
  --             dataOut => dmaHistDumpS );

  GEN_FMC : for i in 0 to NFMC_G-1 generate

    U_EventSel : entity l2si_core.EventHeaderCache
--      generic map ( DEBUG_G => false )
      port map ( rst            => evrRst,
                 wrclk          => evrClk,
                 enable         => configE.acqEnable,
                 partition      => configE.partition,   
                 cacheenable    => configE.enable(i),
                 timing_prompt  => timingHeader_prompt,
                 expt_prompt    => exptBus,
                 timing_aligned => timingHeader_aligned,
                 expt_aligned   => exptBus_aligned,
                 pdata          => trigData (i),
                 pdataV         => trigDataV(i),
                 cntWrFifo      => wrFifoCnt(i),
                 rstFifo        => rstFifo  (i),
                 msgDelay       => msgDelayGet(i),
                 cntL0          => cntL0    (i),
                 cntOflow       => cntOflow (i),
                 debug          => debugS   (i),
                 debugv         => debugSV  (i),
                 --
                 rdclk          => dmaClk,
                 advance        => eventHdrRd(i),
                 valid          => eventHdrV (i),
                 pmsg           => pmsg      (i),
                 phdr           => phdr      (i),
                 cntRdFifo      => rdFifoCnt (i),
                 hdrOut         => eventHdr  (i));

    eventSelQ(i) <= eventSel(i) and not configE.inhibit;
    eventHdrD(i) <= toSlv(eventHdr(i));

    U_DebugS : entity surf.SynchronizerFifo
      generic map ( DATA_WIDTH_G => 8,
                    ADDR_WIDTH_G => 2 )
      port map ( wr_clk          => dmaClk,
                 din(6 downto 0) => debug (i)(6 downto 0),
                 din(7)          => dmaFull,
                 rd_clk          => evrClk,
                 dout            => debugS(i),
                 valid           => debugSV(i));

    eventSel(i) <= trigData (i).l0a and trigDataV(i);
    
  end generate;
  
  trigSlot     <= trigDataV(0);
  l1in         <= trigData (0).l1e and trigDataV(0);
--  l1ina        <= trigData (0).l1a;
  l1ina        <= '1';
  status.msgDelayGet <= msgDelayGet(0);
  status.headerCntL0 <= cntL0(0);
  status.headerCntOF <= cntOflow(0);
  
  U_EventDma : entity work.QuadAdcEvent
    generic map ( TPD_G               => TPD_G,
                  FIFO_ADDR_WIDTH_C   => FIFO_ADDR_WIDTH_C,
                  NFMC_G              => NFMC_G,
                  SYNC_BITS_G         => SYNC_BITS_G,
                  DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G,
                  BASE_ADDR_C         => BASE_ADDR_C )
    port map (    axilClk         => axiClk,
                  axilRst         => axiRst,
                  axilReadMaster  => axilReadMasters (1),
                  axilReadSlave   => axilReadSlaves  (1),
                  axilWriteMaster => axilWriteMasters(1),
                  axilWriteSlave  => axilWriteSlaves (1),
                  --
                  eventClk   => evrClk,
                  trigArm    => eventSelQ(0),
                  l1in       => l1in,
                  l1ina      => l1ina,
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
                  --dmaFullThr => dmaFullThrS(FIFO_ADDR_WIDTH_C-1 downto 0),
                  dmaFullS   => dmaFull,
                  dmaFullCnt => dmaFullCnt,
                  dmaMaster  => axisMaster,
                  dmaSlave   => axisSlave ,
                  status     => status.eventCache,
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
                  cntOut       => status.eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

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
--                  dmaFullThr          => dmaFullThr,
                  --dmaHistEna          => dmaHistEna,
                  adcSyncRst          => adcSyncRst,
                  fmcRst              => idmaRst   ,
                  fbRst               => fbPhyRst  ,
                  fbPLLRst            => fbPllRst  ,
                  -- status
                  irqReq              => irqRequest   ,
                  rstCount            => rstCount     ,
                  dmaClk              => dmaClk,
                  status              => status );

  -- Synchronize configurations to evrClk
  vConfig <= toSlv       (config);
  configE <= toQadcConfig(vConfigE);
  configA <= toQadcConfig(vConfigA);
  configF <= toQadcConfig(vConfigF);
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
  U_ConfigF : entity surf.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => timingFbClk,
                  rst     => timingFbRst,
                  dataIn  => vConfig,
                  dataOut => vConfigF );

  --Sync_dmaFullThr : entity surf.SynchronizerVector
  --  generic map ( TPD_G   => TPD_G,
  --                WIDTH_G => 24 )
  --  port map (    clk     => dmaClk,
  --                rst     => idmaRst,
  --                dataIn  => dmaFullThr,
  --                dataOut => dmaFullThrS );

  Sync_partAddr : entity surf.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => status.partitionAddr'length )
    port map  ( clk     => axiClk,
                dataIn  => paddr,
                dataOut => status.partitionAddr );
  
  --Sync_dmaEnable : entity surf.Synchronizer
  --  generic map ( TPD_G   => TPD_G )
  --  port map (    clk     => evrClk,
  --                rst     => evrRst,
  --                dataIn  => dmaHistEna,
  --                dataOut => dmaHistEnaS );

  seq: process (evrClk) is
  begin
    if rising_edge(evrClk) then
      trigOut <= eventSelQ(0) ;
      if (exptBus.valid = '1' and evrBus.strobe = '1' and
          exptBus.message.partitionAddr(28)='1') then
        paddr <= exptBus.message.partitionAddr;
      end if;
    end if;
  end process seq;

  Sync_dmaFullS : entity surf.Synchronizer
    port map ( clk     => evrClk,
               dataIn  => dmaFull,
               dataOut => dmaFullS );

  Sync_dmaFullSS : entity surf.Synchronizer
    port map ( clk     => timingFbClk,
               dataIn  => dmaFull,
               dataOut => dmaFullSS );

  process (timingFbClk) is
  begin
    if rising_edge(timingFbClk) then
      dmaFullV <= (others=>'0');
      dmaFullV(conv_integer(configF.partition(0))) <= dmaFullSS;
    end if;
  end process;
                      
  Sync_dmaCtrlCount : entity surf.SynchronizerFifo
    generic map ( TPD_G        => TPD_G,
                  DATA_WIDTH_G => 32 )
    port map    ( wr_clk       => dmaClk,
                  din          => dmaFullCnt,
                  rd_clk       => axiClk,
                  dout         => status.dmaCtrlCount );

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
  
  comb : process ( axiRst, r, wrFifoCnt, rdFifoCnt,
                   phaseValue, phaseCount, 
                   axilWriteMasters(2), axilReadMasters(2) ) is
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn( ep,
                     axilWriteMasters(2), axilReadMasters(2),
                     v.axilWriteSlave, v.axilReadSlave );

    for i in 0 to NFMC_G-1 loop
      axiSlaveRegisterR ( ep, toSlv(i*8+0,8), 0, wrFifoCnt(i) );
      axiSlaveRegisterR ( ep, toSlv(i*8+4,8), 0, rdFifoCnt(i) );
    end loop;

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
