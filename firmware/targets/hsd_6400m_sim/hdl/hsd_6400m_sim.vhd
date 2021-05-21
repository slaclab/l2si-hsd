-----------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_dualv2_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2021-05-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.std_logic_unsigned.all;

use STD.textio.all;
use ieee.std_logic_textio.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp3Pkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use work.QuadAdcPkg.all;
use surf.SsiPkg.all;
use surf.AxiPkg.all;
use work.FmcPkg.all;
use work.AxiLiteSimPkg.all;

library unisim;
use unisim.vcomponents.all;

entity hsd_6400m_sim is
end hsd_6400m_sim;

architecture top_level_app of hsd_6400m_sim is

   constant NCHAN_C : integer := 2;
   constant NFMC_C  : integer := 2;

   signal rst      : sl;
   
    -- AXI-Lite and IRQ Interface
   signal regClk    : sl;
   signal regRst    : sl;
   signal axilWriteMaster     : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave      : AxiLiteWriteSlaveType;
   signal axilReadMaster      : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave       : AxiLiteReadSlaveType;

   constant ADC_INDEX_C       : integer := 0;
   constant TEM_INDEX_C       : integer := 1;
   constant NUM_AXI_MASTERS_C : integer := 2;
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := genAxiLiteConfig( 2, x"00000000", 17, 16 );
   signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
   
   -- DMA
   signal dmaClk            : sl;
   signal dmaRst            : slv(NFMC_C-1 downto 0);
   signal dmaIbMaster       : AxiStreamMasterArray(NFMC_C-1 downto 0);
   signal dmaIbSlave        : AxiStreamSlaveArray (NFMC_C-1 downto 0) := (others=>AXI_STREAM_SLAVE_FORCE_C);

   signal dbgWriteSlave      : AxiLiteWriteSlaveType;
   signal dbgReadSlave       : AxiLiteReadSlaveType;

   signal dbgClk            : sl;
   signal phyClk            : sl;
   signal refTimingClk      : sl;
   signal adcO              : AdcDataArray(3 downto 0);
   signal adcI              : AdcDataArray(4*NFMC_C-1 downto 0);
   signal trigIn            : slv(ROW_SIZE-1 downto 0);
   signal trigSel           : slv(1 downto 0);
   signal trigSlot          : slv(1 downto 0);
   
--   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);

   signal dmaData           : slv(31 downto 0);
   signal dmaUser           : slv( 1 downto 0);

   signal axilDone : sl := '0';

   signal config  : QuadAdcConfigType := (
     enable    => toSlv(1,8),
     partition => (others=>'0'),
     intlv     => "00",
     samples   => toSlv(0,18),
     prescale  => toSlv(0,6),
     offset    => toSlv(0,20),
     acqEnable => '1',
     rateSel   => (others=>'0'),
     destSel   => (others=>'0'),
     inhibit   => '0',
     dmaTest   => '0',
     trigShift => (others=>'0'),
     localId   => (others=>'0') );

   constant DBG_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(ROW_SIZE*2);
   signal dbgIbMaster : AxiStreamMasterType;
   signal evtId   : slv(31 downto 0) := (others=>'0');
   signal fexSize : slv(30 downto 0) := (others=>'0');
   signal fexOvfl : sl := '0';
   signal fexOffs : slv(15 downto 0) := (others=>'0');
   signal fexIndx : slv(15 downto 0) := (others=>'0');

   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;

   -- Timing Interface (timingClk domain) 
   signal xData     : TimingRxType  := TIMING_RX_INIT_C;
   signal timingBus : TimingBusType := TIMING_BUS_INIT_C;
   signal recTimingClk : sl;
   signal recTimingRst : sl;

   signal timingFb          : TimingPhyType;

   constant DMA_AXIS_CONFIG_C : AxiStreamConfigType := (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => ROW_SIZE*2,
     TDEST_BITS_C  => 4,
     TID_BITS_C    => 0,
     TKEEP_MODE_C  => TKEEP_FIXED_C,
     TUSER_BITS_C  => 2,
     TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal dsRxClk      : slv(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsRxRst      : slv(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsRxData     : Slv16Array(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsRxDataK    : Slv2Array (XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsRxData_0   : slv(15 downto 0);
   signal dsRxDataK_0  : slv( 1 downto 0);
   signal dsTxClk      : slv(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsTxRst      : slv(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsTxData     : Slv16Array(XPM_MAX_DS_LINKS_C-1 downto 0);
   signal dsTxDataK    : Slv2Array (XPM_MAX_DS_LINKS_C-1 downto 0);

   signal fmcClk  : slv(NFMC_C-1 downto 0);
   signal pgpRxOut       : Pgp3RxOutType;
   signal msgConfig    : XpmPartMsgConfigType := XPM_PART_MSG_CONFIG_INIT_C;

   constant CMDS_C : AxiLiteWriteCmdArray(0 to 25) := (
     --  Chip Adc Reg
     ( addr => x"00000010", value => x"000000ff" ), -- assert DMA rst
     ( addr => x"00000010", value => x"00000000" ), -- release DMA rst
     ( addr => x"00000014", value => x"40000000" ), -- 1Hz dont care
     ( addr => x"00000018", value => x"00000001" ), -- enable 1 channel
     ( addr => x"0000001C", value => x"00000100" ), -- 256 samples
     -- QuadAdcInterleavePacked
     ( addr => x"00001010", value => x"00000004" ), -- fexBegin
     ( addr => x"00001014", value => x"00002000" ), -- fexLen/prescale
     ( addr => x"00001018", value => x"00040C00" ), -- almostFull
     ( addr => x"00001020", value => x"00000004" ), -- fexBegin
     ( addr => x"00001024", value => x"00100064" ), -- fexLen/prescale
     ( addr => x"00001028", value => x"00040C00" ), -- almostFull
     ( addr => x"00001030", value => x"00000004" ), -- fexBegin
     ( addr => x"00001034", value => x"00200064" ), -- fexLen/prescale
     ( addr => x"00001038", value => x"00040C00" ), -- almostFull
     ( addr => x"00001210", value => x"00000801" ), -- prescale
     ( addr => x"00001218", value => x"0000080E" ), -- fexLen/delay
     ( addr => x"00001220", value => x"00000001" ), -- almostFull
     ( addr => x"00001228", value => x"00000002" ), -- prescale
     ( addr => x"00001000", value => x"00000001" ), -- fexEnable
     -- Chip Adc Reg
     ( addr => x"00000010", value => x"C0000000" ), -- enable
     -- XpmMessageAligner
     ( addr => x"00018020", value => x"0a0b0c0d" ), -- feedback Id
     -- Trigger Event Buffer
     ( addr => x"00019004", value => x"00000000" ), -- partition
     ( addr => x"00019008", value => x"00000010" ), -- fifoPauseThresh
     ( addr => x"0001900C", value => x"00000000" ), -- triggerDelay
     ( addr => x"00019000", value => x"00000003" ), -- enable
     ( addr => x"00019000", value => x"00000001" ) ); -- enable

begin

   dmaData <= dmaIbMaster(0).tData(dmaData'range);
   dmaUser <= dmaIbMaster(0).tUser(dmaUser'range);

   U_ClkSim : entity work.ClkSim
     generic map ( VCO_HALF_PERIOD_G => 21.0 ps,
                   TIM_DIVISOR_G     => 64,
                   PHY_DIVISOR_G     => 2 )
     port map ( phyClk   => phyClk,
                evrClk   => refTimingClk );

   U_QIN : entity work.AdcRamp
     generic map ( DATA_LO_G => x"0000",
                   DATA_HI_G => x"0200" )
     port map ( rst      => rst,
                phyClk   => phyClk,
                dmaClk   => dmaClk,
                ready    => axilDone,
                adcOut   => adcO,
                trigSel  => trigSel(0),
                trigOut  => trigIn );

   GEN_ADC : for i in 0 to 3 generate
     GEN_ROW : for j in 0 to ROW_SIZE-1 generate
       adcI(i+0).data(j) <= x"80" & adcO(i).data(j)(3 downto 0);
       adcI(i+4).data(j) <= x"80" & adcO(i).data(j)(3 downto 0);
     end generate;
   end generate;
   
   process is
   begin 
     dbgClk <= '1';
     wait for 1.2 ns;
     dbgClk <= '0';
     wait for 1.2 ns;
   end process;
  
   process is
   begin
     rst <= '1';
     wait for 100 ns;
     rst <= '0';
     wait;
   end process;
   
   regRst       <= rst;
   recTimingRst <= rst;
   
   process is
   begin
     regClk <= '0';
     wait for 3.2 ns;
     regClk <= '1';
     wait for 3.2 ns;
   end process;
     
   recTimingClk <= dsTxClk  (0);
   xData.data   <= dsTxData (0);
   xData.dataK  <= dsTxDataK(0);
   dsRxClk      <= (others=>recTimingClk);
   dsRxRst      <= dsTxRst;
   dsRxData_0   <= timingFb.data;
   dsRxDataK_0  <= timingFb.dataK;
   dsRxData (0) <= dsRxData_0;
   dsRxDataK(0) <= dsRxDataK_0;
   
   U_XPM : entity l2si_core.XpmSim
     generic map ( USE_TX_REF        => true,
                   ENABLE_DS_LINKS_G => toSlv(1,XPM_MAX_DS_LINKS_C),
                   RATE_DIV_G        => 1 )
     port map ( txRefClk  => refTimingClk,
                dsTxClk   => dsTxClk,
                dsTxRst   => dsTxRst,
                dsTxData  => dsTxData,
                dsTxDataK => dsTxDataK,
                dsRxClk   => dsRxClk,
                dsRxRst   => dsRxRst,
                dsRxData  => dsRxData,
                dsRxDataK => dsRxDataK,
                --
                --bpTxClk    => recTimingClk,
                --bpTxLinkUp => '1',
                --bpTxData   => xData.data,
                --bpTxDataK  => xData.dataK,
                bpTxLinkUp => '0',
                bpRxClk    => '0',
                bpRxClkRst => '0',
                bpRxLinkUp => (others=>'0'),
                bpRxLinkFull => (others=>(others=>'0')) );
                --
--                msgConfig    => msgConfig );

   timingBus.modesel <= '1';
   U_RxLcls : entity lcls_timing_core.TimingFrameRx
     port map ( rxClk               => recTimingClk,
                rxRst               => recTimingRst,
                rxData              => xData,
                messageDelay        => (others=>'0'),
                messageDelayRst     => '0',
                timingMessage       => timingBus.message,
                timingMessageStrobe => timingBus.strobe,
                timingMessageValid  => timingBus.valid,
                timingExtension     => timingBus.extension );

  fmcClk <= (others=>phyClk);
  
  U_Core : entity work.DualAdcCore
    generic map ( DMA_STREAM_CONFIG_G => AXIS_CONFIG_C,
                  BASE_ADDR_C         => AXI_CROSSBAR_MASTERS_CONFIG_C(ADC_INDEX_C).baseAddr,
                  TEM_ADDR_C          => AXI_CROSSBAR_MASTERS_CONFIG_C(TEM_INDEX_C).baseAddr )
    port map (
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => mAxilWriteMasters(ADC_INDEX_C),
      axilWriteSlave      => mAxilWriteSlaves (ADC_INDEX_C),
      axilReadMaster      => mAxilReadMasters (ADC_INDEX_C),
      axilReadSlave       => mAxilReadSlaves  (ADC_INDEX_C),
      --
      temAxilWriteMaster  => mAxilWriteMasters(TEM_INDEX_C),
      temAxilWriteSlave   => mAxilWriteSlaves (TEM_INDEX_C),
      temAxilReadMaster   => mAxilReadMasters (TEM_INDEX_C),
      temAxilReadSlave    => mAxilReadSlaves  (TEM_INDEX_C),
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave ,
      -- EVR Ports
      evrClk              => recTimingClk,
      evrRst              => recTimingRst,
      evrBus              => timingBus,
      timingFbClk         => recTimingClk,
      timingFbRst         => recTimingRst,
      timingFb            => timingFb,
      -- ADC
      gbClk               => '0', -- unused
      adcClk              => dmaClk,
      adcRst              => dmaRst(0),
      adc                 => adcI,
      adcValid            => "11",
      fmcClk              => fmcClk,
      --
      trigSlot            => trigSlot );

  U_XBAR : entity surf.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => regClk,
      axiClkRst        => regRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves (0) => axilWriteSlave,
      sAxiReadMasters (0) => axilReadMaster,
      sAxiReadSlaves  (0) => axilReadSlave,
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

   U_AxiLite : entity work.AxiLiteWriteMasterSim
     generic map ( CMDS => CMDS_C,
                   DELAY_CLKS_G => 0 )
     port map ( clk  => regClk,
                rst  => regRst,
                master => axilWriteMaster,
                slave  => axilWriteSlave,
                done   => open );
   
  U_XTC : entity work.HsdXtc
    generic map ( filename => "hsd.xtc" )
    port map ( axisClk    => dmaClk,
               axisMaster => dmaIbMaster(0),
               axisSlave  => dmaIbSlave (0) );

  throttle_p : process ( dmaClk ) is
    variable count     : slv(7 downto 0) := (others=>'0');
--    constant RELEASE_C : slv(7 downto 0) := toSlv(63,count'length);
    constant RELEASE_C : slv(7 downto 0) := toSlv(3,count'length);
  begin
    if rising_edge(dmaClk) then
      if count = RELEASE_C then
        count      := (others=>'0');
        for i in 0 to NFMC_C-1 loop
          dmaIbSlave(i).tReady <= '1';
        end loop;
      else
        count      := count+1;
        for i in 0 to NFMC_C-1 loop
          dmaIbSlave(i).tReady <= '0';
        end loop;
      end if;
    end if;
  end process;

  U_PgpFb : entity l2si_core.DtiPgp3Fb
    port map ( pgpClk       => dmaClk,
               pgpRst       => dmaRst(0),
               pgpRxOut     => pgpRxOut,
               rxLinkId     => open,
               rxAlmostFull => open );
    
end top_level_app;
