-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_packed.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2024-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Wrapper for feature extraction of raw data stream.  The raw data is passed
--   to a feature extraction module (hsd_fex) and extracted data is received
--   from that module. The extracted data is stamped with an internal counter
--   reset by _sync_.  While a gate is open (_lopen_ -> _lclose)) extracted
--   data that is stamped within that gate (or any gate) is saved in a circular
--   buffer.  Gates may overlap.  Circular buffer addresses of the extracted
--   data corresponding to each gate are saved for readout pending a veto
--   decision (_l1in_/_l1ina_).  The number of free rows of the circular buffer
--   (_free_) and number of free gates (_nfree_) are exported for deadtime
--   control.
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

use work.QuadAdcCompPkg.all;
use work.QuadAdcPkg.all;
use work.FmcPkg.all;
use work.AxiStreamPkg.all;

entity hsd_fex_packed is
  generic ( ALG_ID_G      : integer := 0;
            ALGORITHM_G   : string  := "RAW";
            ILV_G         : integer := 4;
            AXIS_CONFIG_G : surf.AxiStreamPkg.AxiStreamConfigType;
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    --din             :  in Slv44Array(7 downto 0);  -- row of data
    din             :  in AdcWordArray(ILV_G*ROW_SIZE-1 downto 0);
    dvalid          :  in sl;
    lskip           :  in sl;                      -- skip sampling (cache
                                                   -- header for readout)
    lopen           :  in sl;                      -- begin sampling
    lopen_phase     :  in slv(ROW_IDXB-1 downto 0);-- lopen location within the row
    lclose          :  in sl;                      -- end sampling
    lclose_phase    :  in slv(ROW_IDXB-1 downto 0);-- lclose location within the row
    l0tag           :  in slv(4 downto 0) := (others=>'0');
    l1in            :  in sl;                      -- once per lopen
    l1ina           :  in sl;                      -- accept/reject
    l1tag           :  in slv(4 downto 0) := (others=>'0');
    free            : out slv(15 downto 0);        -- unused rows in RAM
    nfree           : out slv( 4 downto 0);        -- unused gates
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    writeaddr       : out slv(15 downto 0);
    readaddr        : out slv(15 downto 0);
    -- readout interface
    axisMaster      : out surf.AxiStreamPkg.AxiStreamMasterType;
    axisSlave       :  in surf.AxiStreamPkg.AxiStreamSlaveType;
    fifoOflow       : out sl;
    -- BRAM interface (clk domain)
    bramWriteMaster : out BRamWriteMasterArray(3 downto 0);
    bramReadMaster  : out BRamReadMasterArray (3 downto 0);
    bramReadSlave   : in  BRamReadSlaveArray  (3 downto 0);
    -- configuration interface
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end hsd_fex_packed;

architecture mapping of hsd_fex_packed is

  constant DEBUG_MBP_C   : boolean := false;
  constant DEBUG_DAT_C   : boolean := false;
  constant COUNT_BITS_C  : integer := 14;
  constant SKIP_T        : slv(COUNT_BITS_C-1 downto 0) := toSlv(4096,COUNT_BITS_C);
  constant TDATA_BYTES_C : integer := 2*ILV_G*ROW_SIZE;
  constant AXIS_CONFIG_C : work.AxiStreamPkg.AxiStreamConfigType := (
      TDATA_BYTES_C => TDATA_BYTES_C,
      TUSER_BITS_C  => 2,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => work.AxiStreamPkg.TKEEP_COMP_C,
      TSTRB_EN_C    => false,
      TUSER_MODE_C  => work.AxiStreamPkg.TUSER_FIRST_LAST_C
    );
  
  type AxisRegType is record
    ireading   : slv(MAX_OVL_BITS_C-1 downto 0);
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    irdsel     : integer;
    first      : sl;
    buff       : slv(127 downto 0);
    axisMaster : work.AxiStreamPkg.AxiStreamMasterType;
  end record;

  constant AXIS_REG_INIT_C : AxisRegType := (
    ireading   => (others=>'0'),
    rdaddr     => (others=>'0'),
    irdsel     => 0,
    first      => '0',
    buff       => (others=>'0'),
    axisMaster => work.AxiStreamPkg.AXI_STREAM_MASTER_INIT_C );

  type RegType is record
    tout       : Slv2Array (ROW_SIZE downto 0);
    dout       : Slv64Array(ROW_SIZE downto 0);    -- cached data from FEX
    douten     : slv(ROW_IDXB-1 downto 0);         -- cached # to write from FEX (0 or ROW_SIZE)
    tin        : Slv2Array(ROW_SIZE-1 downto 0);
    nopen      : slv(MAX_OVL_BITS_C-1 downto 0);
    skip       : slv(15 downto 0);
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    rdtail     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wrfull     : sl;
    sink       : sl;
    wrword     : slv(IDX_BITS downto 0);
    wrdata     : Slv64Array(2*ROW_SIZE downto 0);  -- data queued for RAM
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    free       : slv     (15 downto 0);
    nfree      : slv     ( 4 downto 0);
    axisReg    : AxisRegType;
    sperror    : slv     ( 2 downto 0);
    ilerror    : slv     ( 2 downto 0);
    rsperror   : slv     ( ROW_SIZE-1 downto 0);
    rspdata    : slv     (63 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    tin        => (others=>(others=>'0')),
    nopen      => (others=>'0'),
    skip       => (others=>'0'),
    iempty     => (others=>'0'),
    iopened    => (others=>'0'),
    itrigger   => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    rdtail     => (others=>'0'),
    wrfull     => '0',
    sink       => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    free       => (others=>'0'),
    nfree      => (others=>'0'),
    axisReg    => AXIS_REG_INIT_C,
    sperror    => (others=>'0'),
    ilerror    => (others=>'0'),
    rsperror   => (others=>'0'),
    rspdata    => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal tout   : Slv2Array (ROW_SIZE downto 0);
  signal idout  : Slv16Array(ILV_G*(ROW_SIZE+1)-1 downto 0);
  signal dout   : Slv64Array(ROW_SIZE downto 0);
  signal douten : slv(ROW_IDXB-1 downto 0);  -- number of valid points
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*64-1 downto 0);
  signal configSynct : sl;
  signal configSync  : sl;
  signal bWrite      : sl := '0';

  signal maxisSlave  : work.AxiStreamPkg.AxiStreamSlaveType;
  signal taxisMaster : work.AxiStreamPkg.AxiStreamMasterType;
  signal taxisSlave  : work.AxiStreamPkg.AxiStreamSlaveType;
  
  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0) );
  end component ila_0;

  signal tin0  : slv(7 downto 0);
  signal tout0 : slv(8 downto 0);
  signal dn0   : slv(4*ROW_SIZE-1 downto 0);
  signal dr0,dt0 : slv(4*ROW_SIZE-1 downto 0);
  signal tr0,tt0 : slv(  ROW_SIZE-1 downto 0);
  
  function encodeAddr( addr : slv; off : integer ) return slv is
    variable result : slv(CACHE_ADDR_LEN_C-1 downto 0) := (others=>'0');
  begin
    if off < ROW_SIZE then
      result := addr & toSlv(off,IDX_BITS);
    else
      result := (addr+1) & toSlv(off-ROW_SIZE,IDX_BITS);
    end if;
    return result;
  end encodeAddr;

  procedure resetCache( cache : inout CacheType ) is
  begin
    cache.state := EMPTY_S;
    cache.trigd := WAIT_T;
  end procedure;

begin

  --
  --  Something in this block crashes Vivado
  --
  GENDEBUG_DAT : if DEBUG_DAT_C generate
    --
    --  detect error conditions
    --
    -- U_ILA : ila_0
    --   port map ( clk    => clk,
    --              probe0( 63 downto   0) => r.rspdata,
    --              probe0(119 downto  64) => (others=>'0'),
    --              probe0(127 downto 120) => r.rsperror,
    --              probe0(135 downto 128) => idout( 0)(7 downto 0),
    --              probe0(143 downto 136) => idout( 1)(7 downto 0),
    --              probe0(151 downto 144) => idout( 2)(7 downto 0),
    --              probe0(159 downto 152) => idout( 3)(7 downto 0),
    --              probe0(167 downto 160) => idout( 4)(7 downto 0),
    --              probe0(175 downto 168) => idout( 5)(7 downto 0),
    --              probe0(183 downto 176) => idout( 6)(7 downto 0),
    --              probe0(191 downto 184) => idout( 7)(7 downto 0),
    --              probe0(199 downto 192) => idout( 8)(7 downto 0),
    --              probe0(207 downto 200) => idout( 9)(7 downto 0),
    --              probe0(215 downto 208) => idout(10)(7 downto 0),
    --              probe0(223 downto 216) => idout(11)(7 downto 0),
    --              probe0(231 downto 224) => idout(12)(7 downto 0),
    --              probe0(239 downto 232) => idout(13)(7 downto 0),
    --              probe0(247 downto 240) => idout(14)(7 downto 0),
    --              probe0(250 downto 248) => r.sperror,
    --              probe0(253 downto 251) => r.ilerror,
    --              probe0(255 downto 254) => (others=>'0') );
  end generate;
  
  GENDEBUG_MBP : if DEBUG_MBP_C generate
    U_ILA : ila_0
      port map ( clk      => clk,
                 probe0(  7 downto   0) => r.axisReg.axisMaster.tData(  7 downto   0),
                 probe0( 15 downto   8) => r.axisReg.axisMaster.tData( 23 downto  16),
                 probe0( 23 downto  16) => r.axisReg.axisMaster.tData( 39 downto  32),
                 probe0( 31 downto  24) => r.axisReg.axisMaster.tData( 55 downto  48),
                 probe0( 39 downto  32) => r.axisReg.axisMaster.tData( 71 downto  64),
                 probe0( 47 downto  40) => r.axisReg.axisMaster.tData( 87 downto  80),
                 probe0( 55 downto  48) => r.axisReg.axisMaster.tData(103 downto  96),
                 probe0( 63 downto  56) => r.axisReg.axisMaster.tData(119 downto 112),
                 probe0( 71 downto  64) => r.axisReg.axisMaster.tData(135 downto 128),
                 probe0( 79 downto  72) => r.axisReg.axisMaster.tData(151 downto 144),
                 probe0( 87 downto  80) => r.axisReg.axisMaster.tData(167 downto 160),
                 probe0( 95 downto  88) => r.axisReg.axisMaster.tData(183 downto 176),
                 probe0(103 downto  96) => r.axisReg.axisMaster.tData(199 downto 192),
                 probe0(111 downto 104) => r.axisReg.axisMaster.tData(215 downto 208),
                 probe0(119 downto 112) => r.axisReg.axisMaster.tData(231 downto 224),
                 probe0(           120) => r.axisReg.axisMaster.tValid,
                 probe0(           121) => r.axisReg.axisMaster.tLast,
                 probe0(           122) => maxisSlave.tReady,
                 probe0(127 downto 123) => (others=>'0'),
                 probe0(135 downto 128) => taxisMaster.tData(  7 downto   0),
                 probe0(143 downto 136) => taxisMaster.tData( 23 downto  16),
                 probe0(151 downto 144) => taxisMaster.tData( 39 downto  32),
                 probe0(159 downto 152) => taxisMaster.tData( 55 downto  48),
                 probe0(167 downto 160) => taxisMaster.tData( 71 downto  64),
                 probe0(175 downto 168) => taxisMaster.tData( 87 downto  80),
                 probe0(183 downto 176) => taxisMaster.tData(103 downto  96),
                 probe0(191 downto 184) => taxisMaster.tData(119 downto 112),
                 probe0(199 downto 192) => taxisMaster.tData(135 downto 128),
                 probe0(207 downto 200) => taxisMaster.tData(151 downto 144),
                 probe0(215 downto 208) => taxisMaster.tData(167 downto 160),
                 probe0(223 downto 216) => taxisMaster.tData(183 downto 176),
                 probe0(231 downto 224) => taxisMaster.tData(199 downto 192),
                 probe0(239 downto 232) => taxisMaster.tData(215 downto 208),
                 probe0(247 downto 240) => taxisMaster.tData(231 downto 224),
                 probe0(           248) => taxisMaster.tValid,
                 probe0(           249) => taxisMaster.tLast,
                 probe0(           250) => taxisSlave.tReady,
                 probe0(255 downto 251) => (others=>'0'));

  end generate;

  GEN_DEBUG : if DEBUG_G generate
    GEN_TIN : for i in 0 to 7 generate
      tin0 (i) <= lopen when (i = lopen_phase) else '0';
    end generate;
    GEN_TOUT : for i in 0 to 8 generate
      tout0(i) <= r.tout(i)(0);
    end generate;
    GEN_DN0 : for i in 0 to ROW_SIZE-1 generate
      dn0(i*4+3 downto i*4) <= r.wrdata(i)(3 downto 0);
      dr0(i*4+3 downto i*4) <= r.axisReg.axisMaster.tData(64*i+3 downto 64*i);
      tr0(i) <= r.axisReg.axisMaster.tKeep(8*i);
      dt0(i*4+3 downto i*4) <= taxisMaster.tData(64*i+3 downto 64*i);
      tt0(i) <= taxisMaster.tKeep(8*i);
    end generate;
    -- debug writing to BRAM
    U_ILAW : ila_0
      port map ( clk                    => clk,
                 probe0(  7 downto   0) => tin0,
                 probe0( 16 downto   8) => tout0,
                 probe0( 31 downto  17) => r.cache(conv_integer(r.axisReg.ireading)).baddr(14 downto 0),
                 probe0( 46 downto  32) => r.cache(conv_integer(r.axisReg.ireading)).eaddr(14 downto 0),
                 probe0( 51 downto  47) => r.wrword(4 downto 0),
                 probe0( 52)            => r.wrfull,
                 probe0( 68 downto  53) => r.skip,
                 probe0( 69)            => lskip,
                 probe0( 73 downto  70) => r.axisReg.ireading,
                 probe0(113 downto  74) => dn0,
                 probe0(255 downto 114) => (others=>'0') );

    U_ILAR : ila_0 
      port map ( clk                  => clk,
                 probe0(           0) => r.axisReg.axisMaster.tValid,
                 probe0(           1) => r.axisReg.axisMaster.tLast,
                 probe0(33 downto  2) => r.axisReg.axisMaster.tData( 31 downto   0),
                 probe0(65 downto 34) => r.axisReg.axisMaster.tData(159 downto 128),
                 probe0(105 downto  66) => dr0,
                 probe0(115 downto 106) => tr0,
                 probe0(           116) => taxisMaster.tLast,
                 probe0(156 downto 117) => dt0,
                 probe0(166 downto 157) => tt0,
                 probe0(255 downto 167) => (others=>'0') );
  end generate GEN_DEBUG;

  U_Packer : entity work.AxiStreamMBytePacker
    generic map ( MBYTES_G        => 8,
                  SLAVE_CONFIG_G  => AXIS_CONFIG_C,
                  MASTER_CONFIG_G => work.AxiStreamPkg.toAxiStreamConfig(AXIS_CONFIG_G) )
    port map ( axiClk       => clk,
               axiRst       => rst,
               sAxisMaster  => r.axisReg.axisMaster,
               sAxisOverflow=> fifoOflow,
               sAxisSlave   => maxisSlave,
               mAxisMaster  => taxisMaster,
               mAxisSlave   => taxisSlave );

  taxisSlave <= work.AxiStreamPkg.toAxiStreamSlave (axisSlave);
  axisMaster <= work.AxiStreamPkg.toAxiStreamMaster(taxisMaster);
  status     <= r.cache;
  readaddr   <= resize(rdaddr,16);
  writeaddr  <= resize(r.wraddr,16);

  GEN_CHAN : for j in 0 to 3 generate
    bramWriteMaster(j).en   <= '1';
    bramWriteMaster(j).addr <= r.wraddr;
    bramReadMaster (j).en   <= '1';
    bramReadMaster (j).addr <= rdaddr;
    GEN_BRAMWR : for i in 0 to ROW_SIZE-1 generate
      bramWriteMaster(j).data(16*i+15 downto 16*i) <= r.wrdata(i)(16*j+15 downto 16*j);
      rddata(64*i+16*j+15 downto 64*i+16*j) <= bramReadSlave(j).data(16*i+15 downto 16*i);
    end generate;
  end generate;

  rstn <= not rst;

  configSynct <= bWrite or rst;
  
  U_ConfigSync : entity surf.RstSync
    port map ( clk      => clk,
               asyncRst => configSynct,
               syncRst  => configSync );
  
  comb : process( r, clear, lopen, lskip, lclose, lopen_phase, lclose_phase,
                  l1in, l1ina, l0tag, l1tag, dvalid,
                  tout, dout, douten, rddata, maxisSlave ) is
    variable v : RegType;
--    variable n : integer range 0 to 2*ROW_SIZE-1;
    variable n : integer;
    variable i,j,k  : integer;
    variable imatch : integer;
    variable flush  : sl;
    variable skip   : sl;
    variable q      : AxisRegType;
    variable pload  : integer;
  begin
    v := r;
    
    v.wrfull  := '0';
    v.sink    := '0';
    v.dout    := dout;
    v.tout    := tout;
    v.douten  := douten;
    v.tin     := (others=>"00");
    v.sperror := (others=>'0');
    v.ilerror := (others=>'0');
    v.rsperror:= (others=>'0');

    --  Cache the skip status (begin)
    if lopen = '1' then
      v.skip(conv_integer(r.nopen)) := lskip;
      v.tin(conv_integer(lopen_phase ))(0) := not lskip;
    end if;
    
    if lclose = '1' then
      v.skip := '0' & r.skip(r.skip'left downto 1);
      if r.skip(0) = '0' then
        v.tin(conv_integer(lclose_phase))(1) := lclose;
      end if;
    end if;

    if lopen = '1' and lclose = '0' then
      v.nopen := r.nopen+1;
    elsif lopen = '0' and lclose = '1' then
      v.nopen := r.nopen-1;
    end if;
    --  Cache the skip status (end)
    
    flush     := '0';

    --
    --  Push the data to RAM (begin)
    --  If a complete row was written, shift away
    --
    if r.wrfull='1' then
      v.wrdata(ROW_SIZE downto 0) := r.wrdata(2*ROW_SIZE downto ROW_SIZE);
      if r.free/=0 then
        v.wraddr := r.wraddr+1;
      else
        v.sink := '1';
      end if;
    end if;

    k := conv_integer(r.wrword);

    for i in r.dout'range loop
      v.wrdata(k+i) := r.dout(i);
    end loop;
    n := k + conv_integer(r.douten);

    if n >= ROW_SIZE then
      v.wrfull := '1';
      n := n-ROW_SIZE;
    end if;
    v.wrword := toSlv(n,IDX_BITS+1);
    --  Push the data to RAM (end)

    --
    --  check if data was truncated while the gate was open
    --
    if r.sink = '1' then
      for i in r.cache'range loop
        if r.cache(i).state = OPEN_S then
          v.cache(i).ovFlow := '1';
        end if;
      end loop;  -- i
    end if;
    
    --
    --  check if a gate has closed; latch time
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(1)='1' and j<r.douten then  -- lclose
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
      i := conv_integer(r.iopened);
      v.iopened := r.iopened+1;
      v.cache(i).state  := CLOSED_S;
      v.cache(i).eaddr  := encodeAddr( v.wraddr, k+imatch );
      v.cache(i).drows  := conv_integer(v.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS)-
                                        r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS));
      v.cache(i).didxs  := conv_integer(v.cache(i).eaddr(IDX_BITS-1 downto 0)) -
                           conv_integer(r.cache(i).baddr(IDX_BITS-1 downto 0));
      -- correct for stream header buffering first 16 bytes
--      v.cache(i).eaddr  := v.cache(i).eaddr + toSlv(8/ILV_G,CACHE_ADDR_LEN_C);
    end if;

    --
    --  check if a gate has opened; latch sample location
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(0)='1' and j<r.douten then  -- lopen
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
        i := conv_integer(r.iempty);
        v.iempty := r.iempty+1;
        v.cache(i).state  := OPEN_S;
--      v.cache(i).trigd  := WAIT_T;  -- l1t can precede open
--        v.cache(i).skip   := r.lskip;
--        v.cache(i).mapd   := END_M; -- look for close
        v.cache(i).baddr  := encodeAddr( v.wraddr, k+imatch );
        --
        --  Check if we have mistakenly triggered an occupied buffer
        --
        if r.cache(i).state /= EMPTY_S then
          v.cache(i).ovflow := '1';
        else
          v.cache(i).ovflow := '0';
        end if;
    end if;
        
    --
    --  Capture veto decision
    --
    if l1in = '1' then
      i := conv_integer(r.itrigger);
      if l1ina = '1' then
        v.cache(i).trigd := ACCEPT_T;
        v.cache(i).tag   := l1tag;
        v.cache(i).valid := dvalid;  -- is there a better time to latch this?
      else
        v.cache(i).trigd := REJECT_T;
      end if;
      v.itrigger := r.itrigger+1;
    end if;

    --
    --  Stream out data for pending event buffers
    --
    q := v.axisReg;
    i := conv_integer(q.ireading);

    v.free := resize(r.rdtail - r.wraddr,r.free'length) - 1;
      
    if r.cache(i).state = EMPTY_S then
      v.nfree := toSlv(r.cache'length,r.nfree'length);
    else
      v.nfree := resize(q.ireading-r.iempty,r.nfree'length);
    end if;
      
    if maxisSlave.tReady='1' then
      q.axisMaster.tValid := '0';
    end if;

    if q.axisMaster.tValid='0' then
      q.axisMaster.tLast := '0';

      if (r.cache(i).state = EMPTY_S or
          r.cache(i).skip = '1' ) then
        v.rdtail := r.wraddr;
      else
        v.rdtail := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
      end if;

      if (r.cache(i).state = CLOSED_S) then
--          and r.cache(i).mapd = DONE_M) then
        case r.cache(i).trigd is
          when WAIT_T   => null;
          when REJECT_T =>
            resetCache(v.cache(i));
            q.ireading := q.ireading+1;
          when ACCEPT_T =>
            v.cache(i).state := READING_S;
            skip := r.cache(i).skip;
            if skip = '1' then 
              resetCache(v.cache(i));
              q.ireading := q.ireading+1;
            else
              --
              --  Prepare reading from recorded data RAM
              --
              q.rdaddr := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
              --
              --  Form stream header word
              --
              q.first := '1';
              q.axisMaster.tValid := '1';
              pload := r.cache(i).didxs;
              pload := pload + ROW_SIZE*r.cache(i).drows;
              pload := pload*ILV_G;
              q.axisMaster.tData(29 downto 0) := toSlv(pload,30);
              q.axisMaster.tData(30) := not r.cache(i).valid;
              q.axisMaster.tData(31) := r.cache(i).ovflow;
              q.axisMaster.tData( 47 downto  32) := toSlv(0,16);         -- boff,eoff
              q.axisMaster.tData( 55 downto  48) := toSlv(i,8);         -- buffer
              q.axisMaster.tData( 63 downto  56) := toSlv(ALG_ID_G,8);  -- stream
              q.axisMaster.tData( 79 downto  64) := resize(r.cache(i).toffs,16);
              q.axisMaster.tData( 95 downto  80) := resize(r.cache(i).tag  ,16);
              q.axisMaster.tData(111 downto  96) := resize(r.cache(i).baddr,16);
              q.axisMaster.tData(127 downto 112) := resize(r.cache(i).eaddr,16);
              q.axisMaster.tKeep := work.AxiStreamPkg.genTKeep(16);
              if r.cache(i).eaddr = r.cache(i).baddr then
                --  Payload reduced to zero
                q.axisMaster.tLast := '1';
                resetCache(v.cache(i));
                q.ireading := q.ireading+1;
              end if;
            end if;
          when others => null;
        end case;
      elsif r.cache(i).state = READING_S then
        q.axisMaster.tValid := '1';
        k := 2*ILV_G*conv_integer(r.cache(i).baddr(IDX_BITS-1 downto 0));
        q.axisMaster.tKeep := work.AxiStreamPkg.genTKeep(2*ILV_G*ROW_SIZE);
        for j in 0 to 2*ILV_G*ROW_SIZE-1 loop
          if (q.first = '1' and j<k) then
            q.axisMaster.tKeep(j) := '0';
          end if;
        end loop;
        if q.rdaddr = r.cache(i).eaddr(q.rdaddr'left+IDX_BITS downto IDX_BITS) then
          k := 2*ILV_G*conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0));
          for j in 0 to 2*ILV_G*ROW_SIZE-1 loop
            if (j >= k) then
              q.axisMaster.tKeep(j) := '0';
            end if;
          end loop;
          q.axisMaster.tLast := '1';
          resetCache(v.cache(i));
          q.ireading := q.ireading+1;
        elsif ((q.rdaddr+1 = r.cache(i).eaddr(q.rdaddr'left+IDX_BITS downto IDX_BITS)) and
               r.cache(i).eaddr(IDX_BITS-1 downto 0)=0) then
          q.axisMaster.tLast := '1';
          resetCache(v.cache(i));
          q.ireading := q.ireading+1;
        end if;
        q.axisMaster.tData(rddata'range) := rddata;
        q.rdaddr := q.rdaddr+1;
        q.first  := '0';

        for j in 0 to ROW_SIZE-1 loop
          if (q.axisMaster.tKeep(j*2*ILV_G)='1' and rddata(64*j+15)='1'
              and (rddata(64*j+31 downto 64*j+16)/=x"8000" or
                   rddata(64*j+47 downto 64*j+32)/=x"8000" or
                   rddata(64*j+63 downto 64*j+48)/=x"8000")) then
            v.rsperror(j) := '1';
            v.rspdata     := rddata(64*j+63 downto 64*j);
          end if;
        end loop;
      end if;
      v.axisReg := q;
    end if;

    for i in 0 to 2 loop
      if r.douten(0)='1' then
        if (r.dout(0)(15)='1' and r.dout(0)(16*i+31 downto 16*i+16)/=x"8000") then
          v.sperror(i) := '1';
        end if;
        if (r.dout(0)(15)='0' and r.dout(0)(16*i+31 downto 16*i+16)/=r.dout(0)(15 downto 0)) then
          v.ilerror(i) := '1';
        end if;
      end if;
    end loop;
    
    if clear='1' then
      v := REG_INIT_C;
    end if;

    r_in   <= v;
    free   <= r.free;
    nfree  <= r.nfree;
    rdaddr <= v.axisReg.rdaddr;
  end process;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;

  GEN_DO_I : for i in 0 to ROW_SIZE generate
    GEN_DO_J : for j in 0 to ILV_G-1 generate
    dout(i)(j*16+15 downto j*16) <= idout(i*ILV_G+j);
    end generate;
  end generate;

  assert (ALGORITHM_G = "NAT" or
          ALGORITHM_G = "NAF" or
          ALGORITHM_G = "NTR" or    
          (ALGORITHM_G = "NCH" and ROW_SIZE=8) or
          (ALGORITHM_G = "NCH" and ROW_SIZE=10)) report "Unknown fex module" severity failure;

  GEN_NAT : if ALGORITHM_G = "NAT" generate
    U_FEX : entity work.hsd_thr_ilv_native
      generic map ( ILV_G => ILV_G,
                    BASELINE => ("01" & toSlv(0,AdcWord'length-2)) )
      port map ( ap_clk          => clk,
                 ap_rst_n        => rstn,
                 sync            => configSync,
                 x               => din,
                 tin             => r.tin,
                 y               => idout,
                 tout            => tout,
                 yv              => douten,
                 axilReadMaster  => axilReadMaster,
                 axilReadSlave   => axilReadSlave,
                 axilWriteMaster => axilWriteMaster,
                 axilWriteSlave  => axilWriteSlave );
  end generate;

  GEN_NAF : if ALGORITHM_G = "NAF" generate
    U_FEX : entity work.hsd_thr_ilv_native_fine
      generic map ( ILV_G => ILV_G,
                    BASELINE => ("01" & toSlv(0,AdcWord'length-2)) )
      port map ( ap_clk          => clk,
                 ap_rst_n        => rstn,
                 sync            => configSync,
                 x               => din,
                 tin             => r.tin,
                 y               => idout,
                 tout            => tout,
                 yv              => douten,
                 axilReadMaster  => axilReadMaster,
                 axilReadSlave   => axilReadSlave,
                 axilWriteMaster => axilWriteMaster,
                 axilWriteSlave  => axilWriteSlave );
  end generate;

  GEN_NTR : if ALGORITHM_G = "NTR" generate
    U_FEX : entity work.hsd_raw_ilv_native
      generic map ( ILV_G   => ILV_G )
      port map ( ap_clk          => clk,
                 ap_rst_n        => rstn,
                 sync            => configSync,
                 x               => din,
                 tin             => r.tin,
                 y               => idout,
                 tout            => tout,
                 yv              => douten,
                 axilReadMaster  => axilReadMaster,
                 axilReadSlave   => axilReadSlave,
                 axilWriteMaster => axilWriteMaster,
                 axilWriteSlave  => axilWriteSlave );
  end generate;

  GEN_NCH : if ALGORITHM_G = "NCH" generate
    GEN_126 : if ROW_SIZE = 8 generate
      U_FEX : entity work.hsd_raw_mux_native
        generic map ( ID_G    => ALG_ID_G,
                      ILV_G   => ILV_G )
        port map ( ap_clk          => clk,
                   ap_rst_n        => rstn,
                   sync            => configSync,
                   x               => din,
                   tin             => r.tin,
                   y               => idout,
                   tout            => tout,
                   yv              => douten,
                   axilReadMaster  => axilReadMaster,
                   axilReadSlave   => axilReadSlave,
                   axilWriteMaster => axilWriteMaster,
                   axilWriteSlave  => axilWriteSlave );
    end generate;
    GEN_134 : if ROW_SIZE = 10 generate
      U_FEX : entity work.hsd_raw_mux_native_134
        generic map ( ID_G    => ALG_ID_G,
                      ILV_G   => ILV_G )
        port map ( ap_clk          => clk,
                   ap_rst_n        => rstn,
                   sync            => configSync,
                   x               => din,
                   tin             => r.tin,
                   y               => idout,
                   tout            => tout,
                   yv              => douten,
                   axilReadMaster  => axilReadMaster,
                   axilReadSlave   => axilReadSlave,
                   axilWriteMaster => axilWriteMaster,
                   axilWriteSlave  => axilWriteSlave );
    end generate;
  end generate;

end mapping;

