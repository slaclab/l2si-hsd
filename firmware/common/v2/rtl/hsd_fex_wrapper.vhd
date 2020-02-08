-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_wrapper.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-09-30
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
use work.FmcPkg.all;
use work.QuadAdcCompPkg.all;
use work.QuadAdcPkg.all;

entity hsd_fex_wrapper is
  generic ( AXIS_CONFIG_G : AxiStreamConfigType;
            ALGORITHM_G   : string := "RAW";
            STREAM_ID_G   : integer := 0;
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    din             :  in AdcData;                 -- row of data
    lskip           :  in sl;                      -- skip sampling (cache
                                                   -- header for readout)
    lopen           :  in sl;                      -- begin sampling
    lopen_phase     :  in slv(2 downto 0);         -- lopen location within the row
    lclose          :  in sl;                      -- end sampling
    lclose_phase    :  in slv(2 downto 0);         -- lclose location within the row
    l1in            :  in sl;                      -- once per lopen
    l1ina           :  in sl;                      -- accept/reject
    free            : out slv(15 downto 0);        -- unused rows in RAM
    nfree           : out slv( 4 downto 0);        -- unused gates
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    debug           : out slv(31 downto 0);
    -- readout interface
    axisMaster      : out AxiStreamMasterType;
    axisSlave       :  in AxiStreamSlaveType;
    -- BRAM interface (clk domain)
    bramWriteMaster : out BRamWriteMasterType;
    bramReadMaster  : out BRamReadMasterType;
    bramReadSlave   : in  BRamReadSlaveType;
    -- configuration interface
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end hsd_fex_wrapper;

architecture mapping of hsd_fex_wrapper is

  constant LATENCY_C    : integer := 0;
  constant COUNT_BITS_C : integer := 14;
  constant SKIP_T       : slv(COUNT_BITS_C-1 downto 0) := toSlv(4096,COUNT_BITS_C);
  constant DBITS        : integer := AXIS_CONFIG_G.TDATA_BYTES_C*8;
  
  type RegType is record
    tout       : Slv2Array (ROW_SIZE downto 0);
    dout       : Slv16Array(ROW_SIZE downto 0);    -- cached data from FEX
    douten     : slv(ROW_IDXB-1 downto 0);                  -- cached # to write from FEX (0 or ROW_SIZE)
    tin        : Slv2Array(ROW_SIZE-1 downto 0);
    lskip      : sl;
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    ireading   : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    rdtail     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wrfull     : sl;
    wrword     : slv(IDX_BITS downto 0);
    wrdata     : Slv16Array(2*ROW_SIZE downto 0);  -- data queued for RAM
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    free       : slv     (15 downto 0);
    nfree      : slv     ( 4 downto 0);
    axisMaster : AxiStreamMasterType;
    debug      : slv     (31 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    tin        => (others=>(others=>'0')),
    lskip      => '0',
    iempty     => (others=>'0'),
    iopened    => (others=>'0'),
    ireading   => (others=>'0'),
    itrigger   => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    rdaddr     => (others=>'0'),
    rdtail     => (others=>'0'),
    wrfull     => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    free       => (others=>'0'),
    nfree      => (others=>'0'),
    axisMaster => axiStreamMasterInit(AXIS_CONFIG_G),
    debug      => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal tout   : Slv2Array (ROW_SIZE downto 0);
  signal dout   : Slv16Array(ROW_SIZE downto 0);
  signal douten : slv(ROW_IDXB-1 downto 0);  -- number of valid points
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*16-1 downto 0);
  signal wrdata : slv(ROW_SIZE*16-1 downto 0);
  signal maxisSlave : AxiStreamSlaveType;
  signal configSynct : sl;
  signal configSync  : sl;
  signal bWrite      : sl := '0';
  signal tin_dbg     : slv(2*ROW_SIZE-1 downto 0);
  signal tout_dbg    : slv(2*ROW_SIZE+1 downto 0);
  
  constant DEBUG_C : boolean := DEBUG_G;
  
  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal test : slv(6 downto 0);
begin

  status <= r.cache;
  
  bramWriteMaster.en   <= '1';
  bramWriteMaster.addr <= r.wraddr;
  bramWriteMaster.data <= wrdata;

  bramReadMaster.en    <= '1';
  bramReadMaster.addr  <= rdaddr;

  rddata <= bramReadSlave.data;

  debug  <= r.debug;
  
  GEN_DEBUG : if DEBUG_C generate
    process (r, tout) is
    begin
      for i in 0 to ROW_SIZE-1 loop
        tin_dbg(2*i+1 downto 2*i) <= r.tin(i);
      end loop;
      for i in 0 to ROW_SIZE loop
        tout_dbg(2*i+1 downto 2*i) <= tout(i);
      end loop;
      for i in 0 to 6 loop
        if ((r.wrdata(i+1)(3 downto 0)=r.wrdata(i)(3 downto 0)+x"1") or
            r.wrdata(i+1)(15)='1' or
            r.wrdata(i)(15)='1') then
          test(i) <= '0';
        else
          test(i) <= '1';
        end if;
      end loop;
    end process;
    
    U_ILA : ila_0
      port map ( clk       => clk,
                 probe0(0) => lopen,
                 probe0(1) => lclose,
                 probe0(2) => l1in,
                 probe0(16 downto  3) => (others=>'0'),
                 probe0(30 downto 17) => r.cache(0).baddr(13 downto 0),
                 probe0(44 downto 31) => r.cache(0).eaddr(13 downto 0),
                 probe0(58 downto 45) => (others=>'0'),
                 probe0(71 downto 59) => r.rdaddr(12 downto 0),
                 probe0(84 downto 72) => r.wraddr(12 downto 0),
                 probe0(85) => r.axisMaster.tValid,
                 probe0(86) => r.axisMaster.tLast,
                 probe0(90 downto 87) => r.iempty,
                 probe0(94 downto 91) => r.iopened,
                 probe0(98 downto 95) => r.ireading,
                 probe0(102 downto 99) => r.itrigger,
                 probe0(118 downto 103) => resize(tin_dbg,16),
                 probe0(136 downto 119) => resize(tout_dbg,18),
                 probe0(143 downto 137) => test,
                 probe0(147 downto 144) => din.data(0)(3 downto 0),
                 probe0(151 downto 148) => din.data(1)(3 downto 0),
                 probe0(155 downto 152) => din.data(2)(3 downto 0),
                 probe0(159 downto 156) => din.data(3)(3 downto 0),
                 probe0(163 downto 160) => din.data(4)(3 downto 0),
                 probe0(167 downto 164) => din.data(5)(3 downto 0),
                 probe0(171 downto 168) => din.data(6)(3 downto 0),
                 probe0(175 downto 172) => din.data(7)(3 downto 0),
                 probe0(180 downto 176) => resize(douten,5),
                 probe0(255 downto 181) => (others=>'0') );
  end generate;
  
  rstn <= not rst;

  axisMaster <= r.axisMaster;
  maxisSlave <= axisSlave;
  configSynct <= bWrite or rst;
  
  U_ConfigSync : entity surf.RstSync
    port map ( clk      => clk,
               asyncRst => configSynct,
               syncRst  => configSync );
  
  --U_RAM : entity surf.SimpleDualPortRam
  --  generic map ( DATA_WIDTH_G => 16*ROW_SIZE,
  --                ADDR_WIDTH_G => rdaddr'length )
  --  port map ( clka   => clk,
  --             ena    => '1',
  --             wea    => '1',
  --             addra  => r.wraddr,
  --             dina   => wrdata,
  --             clkb   => clk,
  --             enb    => '1',
  --             rstb   => rst,
  --             addrb  => rdaddr,
  --             doutb  => rddata );
  
  comb : process( r, clear, lopen, lskip, lclose, lopen_phase, lclose_phase,
                  l1in, l1ina,
                  tout, dout, douten, rddata, maxisSlave ) is
    variable v : RegType;
    variable n : integer;
    variable i,j,k : integer;
    variable imatch : integer;
    variable flush  : sl;
    variable skip   : sl;
    variable hdr    : slv(127 downto 0);
  begin
    v := r;
    
    v.wrfull  := '0';
    v.dout    := dout;
    v.tout    := tout;
    v.douten  := douten;
    v.tin     := (others=>"00");
    v.tin(conv_integer(lopen_phase ))(0) := lopen;
    v.tin(conv_integer(lclose_phase))(1) := lclose;

    if lopen='1' then
      v.lskip   := lskip;
    end if;

    flush     := '0';

    --
    --  Push the data to RAM
    --  If a buffered line was written, shift away
    --
    if r.wrfull='1' then
      v.wrdata(ROW_SIZE downto 0) := r.wrData(2*ROW_SIZE downto ROW_SIZE);
      v.wraddr := r.wraddr+1;
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
    
    --
    --  check if a gate has closed; latch time
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(1)='1' then  -- lclose
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
      i := conv_integer(r.iopened);
      v.iopened := r.iopened+1;
      v.cache(i).state  := CLOSED_S;
      v.cache(i).eaddr  := (v.wraddr & toSlv(0,IDX_BITS)) + toSlv(k+imatch,CACHE_ADDR_LEN_C);
    end if;

    --
    --  check if a gate has opened; latch sample location
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(0)='1' then  -- lopen
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
        i := conv_integer(r.iempty);
        v.iempty := r.iempty+1;
        v.cache(i).state  := OPEN_S;
--      v.cache(i).trigd  := WAIT_T;  -- l1t can precede open
        v.cache(i).skip   := r.lskip;
--        v.cache(i).mapd   := END_M; -- look for close
        v.cache(i).baddr  := (v.wraddr & toSlv(0,IDX_BITS)) + toSlv(k+imatch,CACHE_ADDR_LEN_C);
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
      else
        v.cache(i).trigd := REJECT_T;
      end if;
      v.itrigger := r.itrigger+1;
    end if;

    --
    --  Stream out data for pending event buffers
    --
    if maxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    if v.axisMaster.tValid='0' then
      v.debug(0) := '0';
      i := conv_integer(r.ireading);
      v.axisMaster.tLast := '0';
      if (r.cache(i).state = CLOSED_S) then
--          and r.cache(i).mapd = DONE_M) then
        case r.cache(i).trigd is
          when WAIT_T   => null;
          when REJECT_T =>
            v.cache(i) := CACHE_INIT_C;
            v.ireading := r.ireading+1;
          when ACCEPT_T =>
            v.debug(0) := '1';
            --
            --  Prepare reading from recorded data RAM
            --
            v.rdaddr := r.cache(i).baddr(r.rdaddr'left+IDX_BITS downto IDX_BITS);
            --
            --  Form header word (16B)
            --
            v.axisMaster.tValid := '1';
            hdr := (others=>'0');

            skip := r.cache(i).skip;
            if skip = '1' then
              hdr(30 downto IDX_BITS) := (others=>'0');
            else
              hdr(30 downto IDX_BITS) :=
                resize(r.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) -
                       r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) + 1,
                       31-IDX_BITS);
            end if;
            hdr(31) := r.cache(i).ovflow;
            hdr( 39 downto  32) := resize(r.cache(i).baddr(IDX_BITS-1 downto 0),8);
            hdr( 47 downto  40) := toSlv(8-conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0)),8);
            hdr( 63 downto  48) := toSlv(STREAM_ID_G,8) & toSlv(i,8);
            hdr( 95 downto  64) := resize(r.cache(i).toffs,32);
            hdr(111 downto  96) := resize(r.cache(i).baddr,16);
            hdr(127 downto 112) := resize(r.cache(i).eaddr,16);
            --  Put the header word at the end of the row
            --  (contiguous with the start of channel data)
            v.axisMaster.tData(DBITS-1 downto         0) := (others=>'0');
            v.axisMaster.tData(DBITS-1 downto DBITS-128) := hdr;
            v.cache(i).state := READING_S;
            if skip = '1' then
              v.axisMaster.tLast := '1';
              v.cache(i) := CACHE_INIT_C;
              v.ireading := r.ireading+1;
            end if;
          when others => null;
        end case;
      elsif r.cache(i).state = READING_S then
        --
        --  Continue streaming data from RAM
        --
        v.axisMaster.tValid := '1';
        v.axisMaster.tData(rddata'range) := rddata;
        v.rdaddr := r.rdaddr+1;
        if r.rdaddr = r.cache(i).eaddr(r.rdaddr'left+IDX_BITS downto IDX_BITS) then
          --if (conv_integer(r.cache(i).baddr(IDX_BITS-1 downto 0)) <
          --    conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0))) then
          --  v.cache(i).state := LAST_S;
          --else
            v.axisMaster.tLast := '1';
            v.cache(i) := CACHE_INIT_C;
            v.ireading := r.ireading+1;
          --end if;
        end if;
      --elsif r.cache(i).state = LAST_S then
      --  v.axisMaster.tValid := '1';
      --  v.axisMaster.tData(rddata'range) := rddata;
      --  v.axisMaster.tLast := '1';
      --  v.cache(i) := CACHE_INIT_C;
      --  v.ireading := r.ireading+1;
      end if;
    end if;

    v.free := resize(r.rdtail - r.wraddr,r.free'length);
      
    i := conv_integer(r.ireading);
    if r.cache(i).state = EMPTY_S then
      v.nfree := toSlv(r.cache'length,r.nfree'length);
    else
      v.nfree := resize(r.ireading-r.iempty,r.nfree'length);
    end if;
    
    if (r.cache(i).state = EMPTY_S or
--        r.cache(i).mapd = BEGIN_M or
        r.cache(i).skip = '1' ) then
      v.rdtail := r.wraddr-1;
    else
      v.rdtail := r.cache(i).baddr(r.rdaddr'left+IDX_BITS downto IDX_BITS);
    end if;
      
    if clear='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    for i in ROW_SIZE-1 downto 0 loop
      wrdata(16*i+15 downto 16*i) <= r.wrdata(i);
    end loop;

    rdaddr <= v.rdaddr;
    free   <= r.free;
    nfree  <= r.nfree;
  end process;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;

  
  GEN_RAW : if ALGORITHM_G = "RAW" generate
    GEN126 : if ROW_SIZE=8 generate
      U_FEX : entity work.hsd_raw
        generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
        port map ( ap_clk              => clk,
                   ap_rst_n            => rstn,
                   sync                => configSync,
                   x0_V                => din.data(0),
                   x1_V                => din.data(1),
                   x2_V                => din.data(2),
                   x3_V                => din.data(3),
                   x4_V                => din.data(4),
                   x5_V                => din.data(5),
                   x6_V                => din.data(6),
                   x7_V                => din.data(7),
                   ti0_V               => r.tin(0),
                   ti1_V               => r.tin(1),
                   ti2_V               => r.tin(2),
                   ti3_V               => r.tin(3),
                   ti4_V               => r.tin(4),
                   ti5_V               => r.tin(5),
                   ti6_V               => r.tin(6),
                   ti7_V               => r.tin(7),
                   y0_V                => dout(0),
                   y1_V                => dout(1),
                   y2_V                => dout(2),
                   y3_V                => dout(3),
                   y4_V                => dout(4),
                   y5_V                => dout(5),
                   y6_V                => dout(6),
                   y7_V                => dout(7),
                   y8_V                => dout(8),
                   yv_V                => douten,
                   to0_V               => tout(0),
                   to1_V               => tout(1),
                   to2_V               => tout(2),
                   to3_V               => tout(3),
                   to4_V               => tout(4),
                   to5_V               => tout(5),
                   to6_V               => tout(6),
                   to7_V               => tout(7),
                   to8_V               => tout(8),
                   s_axi_BUS_A_AWVALID => axilWriteMaster.awvalid,
                   s_axi_BUS_A_AWREADY => axilWriteSlave .awready,
                   s_axi_BUS_A_AWADDR  => axilWriteMaster.awaddr(7 downto 0),
                   s_axi_BUS_A_WVALID  => axilWriteMaster.wvalid,
                   s_axi_BUS_A_WREADY  => axilWriteSlave .wready,
                   s_axi_BUS_A_WDATA   => axilWriteMaster.wdata,
                   s_axi_BUS_A_WSTRB   => axilWriteMaster.wstrb(3 downto 0),
                   s_axi_BUS_A_ARVALID => axilReadMaster .arvalid,
                   s_axi_BUS_A_ARREADY => axilReadSlave  .arready,
                   s_axi_BUS_A_ARADDR  => axilReadMaster .araddr(7 downto 0),
                   s_axi_BUS_A_RVALID  => axilReadSlave  .rvalid,
                   s_axi_BUS_A_RREADY  => axilReadMaster .rready,
                   s_axi_BUS_A_RDATA   => axilReadSlave  .rdata,
                   s_axi_BUS_A_RRESP   => axilReadSlave  .rresp,
                   s_axi_BUS_A_BVALID  => bWrite,
                   s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                   s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
      axilWriteSlave .bvalid <= bWrite;
    end generate;
    GEN134 : if ROW_SIZE>8 generate
    U_FEX : entity work.hsd_raw_native
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x                   => din.data,
                 tin                 => r.tin,
                 y                   => dout,
                 tout                => tout,
                 yv                  => douten,
                 axilReadMaster      => axilReadMaster,
                 axilReadSlave       => axilReadSlave,
                 axilWriteMaster     => axilWriteMaster,
                 axilWriteSlave      => axilWriteSlave );
    end generate;
  end generate;
      
  GEN_THR : if ALGORITHM_G = "THR" generate
    GEN126 : if ROW_SIZE=8 generate
      U_FEX : entity work.hsd_thr
        generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
        port map ( ap_clk              => clk,
                   ap_rst_n            => rstn,
                   sync                => configSync,
                   x0_V                => din.data(0),
                   x1_V                => din.data(1),
                   x2_V                => din.data(2),
                   x3_V                => din.data(3),
                   x4_V                => din.data(4),
                   x5_V                => din.data(5),
                   x6_V                => din.data(6),
                   x7_V                => din.data(7),
                   ti0_V               => r.tin(0),
                   ti1_V               => r.tin(1),
                   ti2_V               => r.tin(2),
                   ti3_V               => r.tin(3),
                   ti4_V               => r.tin(4),
                   ti5_V               => r.tin(5),
                   ti6_V               => r.tin(6),
                   ti7_V               => r.tin(7),
                   y0_V                => dout(0),
                   y1_V                => dout(1),
                   y2_V                => dout(2),
                   y3_V                => dout(3),
                   y4_V                => dout(4),
                   y5_V                => dout(5),
                   y6_V                => dout(6),
                   y7_V                => dout(7),
                   y8_V                => dout(8),
                   yv_V                => douten,
                   to0_V               => tout(0),
                   to1_V               => tout(1),
                   to2_V               => tout(2),
                   to3_V               => tout(3),
                   to4_V               => tout(4),
                   to5_V               => tout(5),
                   to6_V               => tout(6),
                   to7_V               => tout(7),
                   to8_V               => tout(8),
                   s_axi_BUS_A_AWVALID => axilWriteMaster.awvalid,
                   s_axi_BUS_A_AWREADY => axilWriteSlave .awready,
                   s_axi_BUS_A_AWADDR  => axilWriteMaster.awaddr(7 downto 0),
                   s_axi_BUS_A_WVALID  => axilWriteMaster.wvalid,
                   s_axi_BUS_A_WREADY  => axilWriteSlave .wready,
                   s_axi_BUS_A_WDATA   => axilWriteMaster.wdata,
                   s_axi_BUS_A_WSTRB   => axilWriteMaster.wstrb(3 downto 0),
                   s_axi_BUS_A_ARVALID => axilReadMaster .arvalid,
                   s_axi_BUS_A_ARREADY => axilReadSlave  .arready,
                   s_axi_BUS_A_ARADDR  => axilReadMaster .araddr(7 downto 0),
                   s_axi_BUS_A_RVALID  => axilReadSlave  .rvalid,
                   s_axi_BUS_A_RREADY  => axilReadMaster .rready,
                   s_axi_BUS_A_RDATA   => axilReadSlave  .rdata,
                   s_axi_BUS_A_RRESP   => axilReadSlave  .rresp,
                   s_axi_BUS_A_BVALID  => bWrite,
                   s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                   s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
      axilWriteSlave .bvalid <= bWrite;
    end generate;
    GEN134 : if ROW_SIZE>8 generate
    U_FEX : entity work.hsd_thr_native
      generic map ( BASELINE => toSlv(2047,12) )
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x                   => din.data,
                 tin                 => r.tin,
                 y                   => dout,
                 tout                => tout,
                 yv                  => douten,
                 axilReadMaster      => axilReadMaster,
                 axilReadSlave       => axilReadSlave,
                 axilWriteMaster     => axilWriteMaster,
                 axilWriteSlave      => axilWriteSlave );
    end generate;
  end generate;

  GEN_NATIVE : if ALGORITHM_G = "NAT" generate
    U_FEX : entity work.hsd_raw_native
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x                   => din.data,
                 tin                 => r.tin,
                 y                   => dout,
                 tout                => tout,
                 yv                  => douten,
                 axilReadMaster      => axilReadMaster,
                 axilReadSlave       => axilReadSlave,
                 axilWriteMaster     => axilWriteMaster,
                 axilWriteSlave      => axilWriteSlave );
  end generate;
    
  
end mapping;
