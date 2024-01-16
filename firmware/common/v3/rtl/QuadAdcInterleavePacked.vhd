-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcInterleavePacked.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2024-01-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Consider having two data formats: one for multi-channels over a certain
--   length and one for single channel any length or multi-channel under a
--   certain length.  The first would be interleaved allowing minimal buffering.
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
use work.QuadAdcCompPkg.all;
use work.FexAlgPkg.all;
use work.AxiStreamPkg.all;

entity QuadAdcInterleavePacked is
  generic ( BASE_ADDR_C   : slv(31 downto 0) := x"00000000";
            AXIS_CONFIG_G : surf.AxiStreamPkg.AxiStreamConfigType;
            ALGORITHM_G   : StringArray;
            IFMC_G        : integer := 0;
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    start           :  in sl;
    shift           :  in slv       (3 downto 0);
    din             :  in AdcWordArray(4*ROW_SIZE-1 downto 0);
    dvalid          :  in sl;
    l1in            :  in sl;
    l1ina           :  in sl;
    l0raw           :  in sl;
    l0tag           :  in slv       (4 downto 0);
    l1tag           :  in slv       (4 downto 0);
    l1v             : out sl;
    l1a             : out sl;
    --
    almost_full     : out sl;
    overflow        : out sl;
    status          : out CacheStatusArray(MAX_STREAMS_C-1 downto 0);
    debug           : out slv(7 downto 0);
    -- readout interface
    axisMaster      : out surf.AxiStreamPkg.AxiStreamMasterType;
    axisSlave       :  in surf.AxiStreamPkg.AxiStreamSlaveType;
    -- RAM interface (4x?)
    bramWriteMaster : out BRamWriteMasterArray(4*ALGORITHM_G'length-1 downto 0);
    bramReadMaster  : out BRamReadMasterArray (4*ALGORITHM_G'length-1 downto 0);
    bramReadSlave   : in  BRamReadSlaveArray  (4*ALGORITHM_G'length-1 downto 0);
    -- configuration interface
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end QuadAdcInterleavePacked;

architecture mapping of QuadAdcInterleavePacked is

  constant NSTREAMS_C   : integer := ALGORITHM_G'length;
  constant MAXSTREAMS_C : integer := 8;

  type TrigState is ( WAIT_T, REJECT_T, ACCEPT_T );
  type PendType is record
    streams    : slv(MAXSTREAMS_C-1 downto 0);
    trigd      : TrigState;
  end record;

  constant PEND_INIT_C : PendType := (
    streams    => (others=>'0'),
    trigd      => WAIT_T );

  type PendArray is array(natural range<>) of PendType;

  constant PAL_C : integer := 32;
  constant PIL_C : integer := 5;
  
  type RegType is record
    fexEnable  : slv(NSTREAMS_C-1 downto 0);  -- include based on prescale
    fexRaw     : slv(NSTREAMS_C-1 downto 0);  -- include based on l0Raw flag
    fexPrescale: Slv10Array(NSTREAMS_C-1 downto 0);
    fexPreCount: Slv10Array(NSTREAMS_C-1 downto 0);
    fexBegin   : Slv20Array(NSTREAMS_C-1 downto 0);
    fexLength  : Slv20Array(NSTREAMS_C-1 downto 0);
    skip       : slv       (NSTREAMS_C-1 downto 0);
    start      : slv       (NSTREAMS_C-1 downto 0);
    l1in       : slv       (NSTREAMS_C-1 downto 0);
    l1ina      : slv       (NSTREAMS_C-1 downto 0);
    ropend     : PendArray (PAL_C-1 downto 0);
    npend      : slv       (PIL_C-1 downto 0);
    ntrig      : slv       (PIL_C-1 downto 0);
    nread      : slv       (PIL_C-1 downto 0);
    nfree      : slv       (PIL_C-1 downto 0);
    aaFullN    : slv       (PIL_C-1 downto 0);
    --nhdr       : slv       ( 3 downto 0);
    --hdrV       : slv       (15 downto 0);
    --hdr        : Slv192Array(15 downto 0);
    --hdrRd      : sl;
    aFull      : Slv16Array(NSTREAMS_C-1 downto 0);
    aFullN     : Slv5Array (NSTREAMS_C-1 downto 0);
    almost_full: slv       (NSTREAMS_C   downto 0);
    overflow   : sl;
    fexb       : slv(NSTREAMS_C-1 downto 0);
    fexn       : integer range 0 to NSTREAMS_C-1;
    axisMaster : work.AxiStreamPkg.AxiStreamMasterType;
    axisSlaves : surf.AxiStreamPkg.AxiStreamSlaveArray(NSTREAMS_C-1 downto 0);
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    fexEnable  => (others=>'0'),
    fexRaw     => (others=>'0'),
    fexPrescale=> (others=>(others=>'0')),
    fexPreCount=> (others=>(others=>'0')),
    fexBegin   => (others=>(others=>'0')),
    fexLength  => (others=>(others=>'0')),
    skip       => (others=>'0'),
    start      => (others=>'0'),
    l1in       => (others=>'0'),
    l1ina      => (others=>'0'),
    ropend     => (others=>PEND_INIT_C),
    npend      => (others=>'0'),
    ntrig      => (others=>'0'),
    nread      => (others=>'0'),
    nfree      => (others=>'0'),
    aaFullN    => (others=>'0'),
    --nhdr       => (others=>'0'),
    --hdr        => (others=>(others=>'0')),
    --hdrV       => (others=>'0'),
    --hdrRd      => '0',
    aFull      => (others=>(others=>'0')),
    aFullN     => (others=>(others=>'0')),
    almost_full=> (others=>'0'),
    overflow   => '0',
    fexb       => (others=>'0'),
    fexn       => 0,
    axisMaster => work.AxiStreamPkg.AXI_STREAM_MASTER_INIT_C,
    axisSlaves => (others=>surf.AxiStreamPkg.AXI_STREAM_SLAVE_INIT_C),
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal lopen, lclose, lskip : slv(NSTREAMS_C-1 downto 0);
  signal lopen_phase, lclose_phase : Slv4Array(NSTREAMS_C-1 downto 0);
  signal free              : Slv16Array(NSTREAMS_C-1 downto 0);
  signal nfree             : Slv5Array (NSTREAMS_C-1 downto 0);

  signal maxilReadMaster   : AxiLiteReadMasterType;
  signal maxilReadSlave    : AxiLiteReadSlaveType;
  signal maxilWriteMaster  : AxiLiteWriteMasterType;
  signal maxilWriteSlave   : AxiLiteWriteSlaveType;
  signal maxilReadMasters  : AxiLiteReadMasterArray (NSTREAMS_C downto 0);
  signal maxilReadSlaves   : AxiLiteReadSlaveArray  (NSTREAMS_C downto 0);
  signal maxilWriteMasters : AxiLiteWriteMasterArray(NSTREAMS_C downto 0);
  signal maxilWriteSlaves  : AxiLiteWriteSlaveArray (NSTREAMS_C downto 0);

  signal axisMasters       : surf.AxiStreamPkg.AxiStreamMasterArray   (NSTREAMS_C-1 downto 0);
  signal axisSlaves        : surf.AxiStreamPkg.AxiStreamSlaveArray    (NSTREAMS_C-1 downto 0);
  signal maxisSlave        : work.AxiStreamPkg.AxiStreamSlaveType;
  signal axisOflow         : slv          (NSTREAMS_C downto 0);
  signal cntOflow          : SlVectorArray(NSTREAMS_C downto 0,7 downto 0);

  signal axisMasterTmp     : work.AxiStreamPkg.AxiStreamMasterType;
  signal axisSlaveTmp      : work.AxiStreamPkg.AxiStreamSlaveType;
  
  constant SAXIS_CONFIG_C : work.AxiStreamPkg.AxiStreamConfigType :=
    work.AxiStreamPkg.toAxiStreamConfig(ssiAxiStreamConfig(32));
  constant MAXIS_CONFIG_C : work.AxiStreamPkg.AxiStreamConfigType :=
    work.AxiStreamPkg.toAxiStreamConfig(AXIS_CONFIG_G);

  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NSTREAMS_C downto 0) := genAxiLiteConfig(NSTREAMS_C+1, BASE_ADDR_C, 12, 8);

  -- signals for debugging
  signal rData : slv(127 downto 0);
  signal sData : slv(127 downto 0);

  constant DEBUG_C : boolean := DEBUG_G;
  constant DEBUG_MBP_C : boolean := false;
  
  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal r_fexb      : slv(MAXSTREAMS_C-1 downto 0) := (others=>'0');
  signal r_fexn      : slv(3 downto 0);
  signal wraddr      : Slv16Array      (NSTREAMS_C-1 downto 0);
  signal rdaddr      : Slv16Array      (NSTREAMS_C-1 downto 0);

  -- signals for simulation
  signal axisMasters_tData : Slv64Array(NSTREAMS_C-1 downto 0);
  signal axisMasters_tKeep : Slv64Array(NSTREAMS_C-1 downto 0);
  signal axisMaster_tData  : slv(63 downto 0);
  signal axisMaster_tKeep  : slv(63 downto 0);
  
begin  -- mapping

  GEN_SIM : for i in 0 to NSTREAMS_C-1 generate
    axisMasters_tData(i) <= axisMasters(i).tData(63 downto 0);
    axisMasters_tKeep(i) <= axisMasters(i).tKeep(63 downto 0);
  end generate;
  axisMaster_tData <= axisMasterTmp.tData(63 downto 0);
  axisMaster_tKeep <= axisMasterTmp.tKeep(63 downto 0);

  GENDEBUG_MBP : if DEBUG_MBP_C generate
    U_ILA : ila_0
      port map ( clk      => clk,
                 probe0(  7 downto   0) => r.axisMaster.tData(  7 downto   0),
                 probe0( 15 downto   8) => r.axisMaster.tData( 23 downto  16),
                 probe0( 23 downto  16) => r.axisMaster.tData( 39 downto  32),
                 probe0( 31 downto  24) => r.axisMaster.tData( 55 downto  48),
                 probe0( 39 downto  32) => r.axisMaster.tData( 71 downto  64),
                 probe0( 47 downto  40) => r.axisMaster.tData( 87 downto  80),
                 probe0( 55 downto  48) => r.axisMaster.tData(103 downto  96),
                 probe0( 63 downto  56) => r.axisMaster.tData(119 downto 112),
                 probe0( 71 downto  64) => r.axisMaster.tData(135 downto 128),
                 probe0( 79 downto  72) => r.axisMaster.tData(151 downto 144),
                 probe0( 87 downto  80) => r.axisMaster.tData(167 downto 160),
                 probe0( 95 downto  88) => r.axisMaster.tData(183 downto 176),
                 probe0(103 downto  96) => r.axisMaster.tData(199 downto 192),
                 probe0(111 downto 104) => r.axisMaster.tData(215 downto 208),
                 probe0(119 downto 112) => r.axisMaster.tData(231 downto 224),
                 probe0(           120) => r.axisMaster.tValid,
                 probe0(           121) => r.axisMaster.tLast,
                 probe0(           122) => maxisSlave.tReady,
                 probe0(127 downto 123) => (others=>'0'),
                 probe0(135 downto 128) => axisMasterTmp.tData(  7 downto   0),
                 probe0(143 downto 136) => axisMasterTmp.tData( 23 downto  16),
                 probe0(151 downto 144) => axisMasterTmp.tData( 39 downto  32),
                 probe0(159 downto 152) => axisMasterTmp.tData( 55 downto  48),
                 probe0(167 downto 160) => axisMasterTmp.tData( 71 downto  64),
                 probe0(175 downto 168) => axisMasterTmp.tData( 87 downto  80),
                 probe0(183 downto 176) => axisMasterTmp.tData(103 downto  96),
                 probe0(191 downto 184) => axisMasterTmp.tData(119 downto 112),
                 probe0(199 downto 192) => axisMasterTmp.tData(135 downto 128),
                 probe0(207 downto 200) => axisMasterTmp.tData(151 downto 144),
                 probe0(215 downto 208) => axisMasterTmp.tData(167 downto 160),
                 probe0(223 downto 216) => axisMasterTmp.tData(183 downto 176),
                 probe0(231 downto 224) => axisMasterTmp.tData(199 downto 192),
                 probe0(239 downto 232) => axisMasterTmp.tData(215 downto 208),
                 probe0(247 downto 240) => axisMasterTmp.tData(231 downto 224),
                 probe0(           248) => axisMasterTmp.tValid,
                 probe0(           249) => axisMasterTmp.tLast,
                 probe0(           250) => axisSlaveTmp.tReady,
                 probe0(255 downto 251) => (others=>'0'));

  end generate;
  
  GENDEBUG : if DEBUG_C generate

    r_fexb <= resize(r.fexb,r_fexb'length);
    r_fexn <= toSlv(r.fexn,r_fexn'length);

    U_ILA : ila_0
      port map ( clk       => clk,
                 probe0(0) => rst,
                 probe0(1) => r.axisMaster.tValid,
                 probe0(2) => r.axisMaster.tLast,
                 probe0(3) => maxisSlave.tReady,
                 probe0(11 downto  4) => r_fexb,
                 probe0(15 downto 12) => r_fexn,
                 probe0(47 downto 16) => r.axisMaster.tData(31 downto 0),
                 probe0(55 downto 48) => (others=>'0'),
                 probe0(63 downto 56) => r.ropend(0).streams,
                 probe0(71 downto 64) => r.ropend(1).streams,
                 probe0(79 downto 72) => r.ropend(2).streams,
                 probe0(87 downto 80) => r.ropend(3).streams,
                 probe0(88)           => start,
                 probe0(89)           => l1in,
                 probe0(90)           => l1ina,
                 probe0( 95 downto  91) => l0tag,
                 probe0(100 downto  96) => l1tag,
                 probe0(105 downto 101) => r.npend,
                 probe0(110 downto 106) => r.ntrig,
                 probe0(115 downto 111) => r.nread,
                 probe0(131 downto 116) => free(0),
                 probe0(136 downto 132) => nfree(0),
                 probe0(152 downto 137) => free(1),
                 probe0(157 downto 153) => nfree(1),
                 probe0(255 downto 158) => (others=>'0') );
  end generate;
    
--  streams <= resize(r.fexEnable,4);
  debug   <= resize(nfree(0),8);

  overflow <= r.overflow or uOr(axisOflow);
              
  GEN_AXIL_ASYNC : entity surf.AxiLiteAsync
    port map ( sAxiClk         => axilClk,
               sAxiClkRst      => axilRst,
               sAxiReadMaster  => axilReadMaster,
               sAxiReadSlave   => axilReadSlave,
               sAxiWriteMaster => axilWriteMaster,
               sAxiWriteSlave  => axilWriteSlave,
               mAxiClk         => clk,
               mAxiClkRst      => rst,
               mAxiReadMaster  => maxilReadMaster,
               mAxiReadSlave   => maxilReadSlave,
               mAxiWriteMaster => maxilWriteMaster,
               mAxiWriteSlave  => maxilWriteSlave );
  
  GEN_AXIL_XBAR : entity surf.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G   => 1,
                  NUM_MASTER_SLOTS_G  => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G    => AXIL_XBAR_CONFIG_C )
    port map ( axiClk           => clk,
               axiClkRst        => rst,
               sAxiReadMasters (0) => maxilReadMaster,
               sAxiReadSlaves  (0) => maxilReadSlave,
               sAxiWriteMasters(0) => maxilWriteMaster,
               sAxiWriteSlaves (0) => maxilWriteSlave,
               mAxiReadMasters     => maxilReadMasters,
               mAxiReadSlaves      => maxilReadSlaves,
               mAxiWriteMasters    => maxilWriteMasters,
               mAxiWriteSlaves     => maxilWriteSlaves );

  GEN_RESIZE : entity work.AxiStreamMBytePacker
    generic map ( MBYTES_G        => 8,
                  SLAVE_CONFIG_G  => SAXIS_CONFIG_C,
                  MASTER_CONFIG_G => MAXIS_CONFIG_C )
    port map ( axiClk        => clk,
               axiRst        => rst,
               sAxisMaster   => r.axisMaster,
               sAxisSlave    => maxisSlave,
               sAxisOverflow => axisOflow(NSTREAMS_C),
               mAxisMaster   => axisMasterTmp,
               mAxisSlave    => axisSlaveTmp );

  axisMaster   <= work.AxiStreamPkg.toAxiStreamMaster( axisMasterTmp );
  axisSlaveTmp <= work.AxiStreamPkg.toAxiStreamSlave ( axisSlave );
  
  GEN_OFLOW : entity surf.SynchronizerOneShotCntVector
    generic map ( COMMON_CLK_G => true,
                  CNT_WIDTH_G  => 8,
                  WIDTH_G      => cntOflow'length )
    port map ( dataIn     => axisOflow,
               rollOverEn => (others=>'0'),
               cntOut     => cntOflow,
               wrClk      => clk,
               rdClk      => clk );
  
  GEN_STR : for i in 0 to NSTREAMS_C-1 generate
    -- l1v   (i) <= lclose(i);
    -- l1a   (i) <= '0';

    U_GATE : entity work.FexGate
      generic map ( WIDTH_G => 20 )
      port map ( clk          => clk,
                 rst          => rst,
                 start        => r.start     (i),
                 handle       => r.skip      (i),
                 phase        => shift,
                 fbegin       => r.fexBegin  (i),
                 flength      => r.fexLength (i),
                 lopen        => lopen       (i),
                 lopen_phase  => lopen_phase (i),
                 lhandle      => lskip       (i),
                 lclose       => lclose      (i),
                 lclose_phase => lclose_phase(i) );

    U_FEX : entity work.hsd_fex_packed
      generic map ( ALG_ID_G      => i,
                    ALGORITHM_G   => ALGORITHM_G(i),
                    AXIS_CONFIG_G => work.AxiStreamPkg.toAxiStreamConfig(SAXIS_CONFIG_C),
                    DEBUG_G       => false ) -- ite(i=0,DEBUG_G,false) )
      port map ( clk               => clk,
                 rst               => rst,
                 clear             => clear,
                 din               => din,
                 dvalid            => dvalid,
                 lskip             => lskip       (i),
                 lopen             => lopen       (i),
                 lopen_phase       => lopen_phase (i),
                 lclose            => lclose      (i),
                 lclose_phase      => lclose_phase(i),
                 l1in              => r.l1in      (i),
                 l1ina             => r.l1ina     (i),
                 l0tag             => l0tag,
                 l1tag             => l1tag,
                 free              => free            (i),
                 nfree             => nfree           (i),
                 status            => status          (i),
                 writeaddr         => wraddr          (i),
                 readaddr          => rdaddr          (i),
                 axisMaster        => axisMasters     (i),
                 axisSlave         => axisSlaves      (i),
                 fifoOflow         => axisOflow       (i),
                 -- BRAM interface
                 bramWriteMaster   => bramWriteMaster (4*i+3 downto 4*i),
                 bramReadMaster    => bramReadMaster  (4*i+3 downto 4*i),
                 bramReadSlave     => bramReadSlave   (4*i+3 downto 4*i),
                 --
                 axilReadMaster    => maxilReadMasters (i+1),
                 axilReadSlave     => maxilReadSlaves  (i+1),
                 axilWriteMaster   => maxilWriteMasters(i+1),
                 axilWriteSlave    => maxilWriteSlaves (i+1) );
  end generate;

  GEN_REM : for i in NSTREAMS_C to MAX_STREAMS_C-1 generate
    -- l1v   (i) <= '0';
    -- l1a   (i) <= '0';
    status(i) <= (others=>CACHE_INIT_C);
  end generate;
  
  process (r, rst, start, clear, free, nfree, l0raw, l1in, l1ina, 
           axisMasters, maxisSlave, axisSlaveTmp, cntOflow, rdaddr, wraddr,
           maxilWriteMasters, maxilReadMasters) is
    variable v     : RegType;
    variable ep    : AxiLiteEndpointType;
    variable i,j   : integer;
  begin  -- process
    v := r;

    v.skip  := (others=>'0');
    v.start := (others=>'0');
    v.l1in  := (others=>'0');
    v.l1ina := (others=>'0');

    -- New --
    -- AxiStream interface
    if maxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    for i in 0 to NSTREAMS_C-1 loop
      v.axisSlaves(i).tReady := '0';
    end loop;
    
    --
    --  Skip prescaled stream headers altogether and indicate in event header.
    --  Skip is determined ahead of time, so should be known.
    --
    if r.fexb(r.fexn)='0' then
      if r.fexn=NSTREAMS_C-1 then
        i := conv_integer(r.nread);
        if r.ropend(i).trigd = ACCEPT_T then
          if v.axisMaster.tValid='0' then
            v.ropend(i).trigd := WAIT_T;
            v.ropend(i).streams := (others=>'0');
            v.fexb  := r.ropend(i).streams(NSTREAMS_C-1 downto 0);
            v.fexn  := 0;
            v.nread := r.nread+1;
            v.axisMaster.tValid := '1';
            v.axisMaster.tLast  := '0';
            if v.fexb=0 then
              v.axisMaster.tLast := '1';
            end if;
            v.axisMaster.tKeep := work.AxiStreamPkg.genTKeep(SAXIS_CONFIG_C.TDATA_BYTES_C);
            v.axisMaster.tData(223 downto 212) := toSlv(1,4) & resize(v.fexb,8);
          end if;
        elsif r.ropend(i).trigd = REJECT_T then
          v.ropend(i).trigd := WAIT_T;
          v.nread := r.nread+1;
        end if;
      else
        v.fexn := r.fexn+1;
      end if;
    elsif v.axisMaster.tValid='0' then
      if axisMasters(r.fexn).tValid='1' then
        v.axisSlaves(r.fexn).tReady := '1';
        v.axisMaster        := toAxiStreamMaster(axisMasters(r.fexn));
        v.axisMaster.tLast  := '0';
        if axisMasters(r.fexn).tLast='1' then
          v.fexb(r.fexn) := '0';
          if v.fexb=0 then
            v.axisMaster.tLast := '1';
          end if;
        end if;
      end if;
    end if;

    -- AxiLite accesses
    axiSlaveWaitTxn( ep,
                     maxilWriteMasters(0), maxilReadMasters(0),
                     v.axilWriteSlave, v.axilReadSlave );

    axiSlaveRegister ( ep, x"00", 0, v.fexEnable );
    axiSlaveRegister ( ep, x"00", 8, v.aaFullN );
    axiSlaveRegister ( ep, x"00",16, v.fexRaw );

    axiSlaveRegisterR( ep, x"04", 0, muxSlVectorArray(cntOflow,NSTREAMS_C) );
    axiSlaveRegisterR( ep, x"04",28, toSlv(NSTREAMS_C,4) );

    axiSlaveRegisterR( ep, x"08", 0, r.fexb );
    axiSlaveRegisterR( ep, x"08", 5, toSlv(r.fexn,3) );
    for i in 0 to NSTREAMS_C-1 loop
      axiSlaveRegisterR( ep, x"08", 8+i, axisMasters(i).tValid );
    end loop;
    axiSlaveRegisterR( ep, x"08",13, maxisSlave.tReady );
    axiSlaveRegisterR( ep, x"08",14, r.axisMaster.tValid );
    axiSlaveRegisterR( ep, x"08",15, axisSlaveTmp.tReady );
    axiSlaveRegisterR( ep, x"08",16, rdaddr(r.fexn) );
    axiSlaveRegisterR( ep, x"0C", 0, r.npend  );
    axiSlaveRegisterR( ep, x"0C", 5, r.ntrig  );
    axiSlaveRegisterR( ep, x"0C",10, r.nread  );
    axiSlaveRegisterR( ep, x"0C",16, wraddr(r.fexn) );

    for i in 0 to NSTREAMS_C-1 loop
      axiSlaveRegister ( ep, toSlv(16*i+16,8), 0, v.fexBegin (i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8), 0, v.fexLength(i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8),20, v.fexPrescale(i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8), 0, v.aFull    (i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8),16, v.aFullN   (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8), 0, free       (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8),16, nfree      (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8),24, muxSlVectorArray(cntOflow,i) );
    end loop;

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    if start = '1' then
      for i in 0 to NSTREAMS_C-1 loop
        if r.fexEnable(i)='1' then
          v.start      (i) := '1';
          if r.fexPreCount(i)=r.fexPrescale(i) then
            v.skip       (i) := '0';
            v.fexPreCount(i) := (others=>'0');
          else
            v.skip       (i) := '1';
            v.fexPreCount(i) := r.fexPreCount(i)+1;
          end if;
        elsif r.fexRaw(i)='1' then
          v.start      (i) := '1';
          v.skip       (i) := not l0raw;
        else
          v.fexPreCount(i) := (others=>'0');
        end if;
      end loop;
      i := conv_integer(r.npend);
      v.ropend(i).streams(NSTREAMS_C-1 downto 0) := v.start and not v.skip;
      v.npend := r.npend+1;

      if r.nfree = 0 then
        v.overflow := '1';
      end if;

    end if;

    if l1in = '1' then
      i := conv_integer(r.ntrig);
      v.l1in := r.ropend(i).streams(NSTREAMS_C-1 downto 0);
      if l1ina = '1' then
        v.l1ina := r.ropend(i).streams(NSTREAMS_C-1 downto 0);
        v.ropend(i).trigd := ACCEPT_T;
      else
        v.ropend(i).trigd := REJECT_T;
      end if;
      v.ntrig := r.ntrig+1;
    end if;        

    v.nfree := r.nread-r.npend-1;
    
    -- almost full interface
    for i in 0 to NSTREAMS_C-1 loop
      if (r.fexEnable(i) = '1' and
          (free (i) < r.aFull (i) or
           nfree(i) < r.aFullN(i))) then
        v.almost_full(i) := '1';
      else
        v.almost_full(i) := '0';
      end if;
    end loop;

    if (r.nfree < r.aaFullN) then
      v.almost_full(NSTREAMS_C) := '1';
    else
      v.almost_full(NSTREAMS_C) := '0';
    end if;
    
    if clear='1' then
      v.fexPreCount := (others=>(others=>'0'));
    end if;

    axisSlaves          <= v.axisSlaves;
    maxilReadSlaves (0) <= r.axilReadSlave;
    maxilWriteSlaves(0) <= r.axilWriteSlave;
    almost_full         <= uOr(r.almost_full);

    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;

    
