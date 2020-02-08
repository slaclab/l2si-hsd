-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_interleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-12-06
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

entity hsd_fex_interleave is
  generic ( ALG_ID_G      : integer := 0;
            ALGORITHM_G   : string  := "RAW";
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    din             :  in Slv44Array(7 downto 0);  -- row of data
    lskip           :  in sl;                      -- skip sampling (cache
                                                   -- header for readout)
    lopen           :  in sl;                      -- begin sampling
    lopen_phase     :  in slv(2 downto 0);         -- lopen location within the row
    lclose          :  in sl;                      -- end sampling
    lclose_phase    :  in slv(2 downto 0);         -- lopen location within the row
    l1in            :  in sl;                      -- once per lopen
    l1ina           :  in sl;                      -- accept/reject
    free            : out slv(15 downto 0);        -- unused rows in RAM
    nfree           : out slv( 4 downto 0);        -- unused gates
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    -- readout interface
    axisMaster      : out AxiStreamMasterType;
    axisSlave       :  in AxiStreamSlaveType;
    -- BRAM interface (clk domain)
    bramWriteMaster : out BRamWriteMasterArray(3 downto 0);
    bramReadMaster  : out BRamReadMasterArray (3 downto 0);
    bramReadSlave   : in  BRamReadSlaveArray  (3 downto 0);
    -- configuration interface
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end hsd_fex_interleave;

architecture mapping of hsd_fex_interleave is

  constant LATENCY_C    : integer := 0;
  constant COUNT_BITS_C : integer := 14;
  constant SKIP_T       : slv(COUNT_BITS_C-1 downto 0) := toSlv(4096,COUNT_BITS_C);
  
  type AxisRegType is record
    ireading   : slv(MAX_OVL_BITS_C-1 downto 0);
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    irdsel     : integer;
    buff       : slv(127 downto 0);
    axisMaster : AxiStreamMasterType;
  end record;

  constant AXIS_REG_INIT_C : AxisRegType := (
    ireading   => (others=>'0'),
    rdaddr     => (others=>'0'),
    irdsel     => 0,
    buff       => (others=>'0'),
    axisMaster => AXI_STREAM_MASTER_INIT_C );

  type RegType is record
    tout       : Slv2Array (ROW_SIZE downto 0);
    dout       : Slv64Array(ROW_SIZE downto 0);    -- cached data from FEX
    douten     : slv(3 downto 0);                  -- cached # to write from FEX (0 or ROW_SIZE)
    tin        : Slv2Array(ROW_SIZE-1 downto 0);
    lskip      : sl;
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    rdtail     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wrfull     : sl;
    wrword     : slv(IDX_BITS downto 0);
    wrdata     : Slv64Array(2*ROW_SIZE downto 0);  -- data queued for RAM
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    free       : slv     (15 downto 0);
    nfree      : slv     ( 4 downto 0);
    axisReg    : AxisRegType;
  end record;
  constant REG_INIT_C : RegType := (
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    tin        => (others=>(others=>'0')),
    lskip      => '0',
    iempty     => (others=>'0'),
    iopened    => (others=>'0'),
    itrigger   => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    rdtail     => (others=>'0'),
    wrfull     => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    free       => (others=>'0'),
    nfree      => (others=>'0'),
    axisReg    => AXIS_REG_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal tout   : Slv2Array (ROW_SIZE downto 0);
  signal dout   : Slv64Array(ROW_SIZE downto 0);
  signal douten : slv(IDX_BITS   downto 0);  -- number of valid points
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*64-1 downto 0);
  signal configSynct : sl;
  signal configSync  : sl;
  signal bWrite      : sl := '0';

  signal maxisSlave  : AxiStreamSlaveType;

  constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(64);
  constant PAD_SAMP_C    : integer := (AXIS_CONFIG_C.TDATA_BYTES_C-16)/2;

  constant ILV_C : integer := 4;
  signal idin  : AdcWordArray(ILV_C*ROW_SIZE-1 downto 0);
  signal idout : Slv16Array  (ILV_C*ROW_SIZE+ILV_C-1 downto 0);
  
begin

  status <= r.cache;

  --U_FIFO : entity surf.AxiStreamFifoV2
  --  generic map ( SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_C,
  --                MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
  --  port map ( -- Slave Port
  --    sAxisClk    => clk,
  --    sAxisRst    => rst,
  --    sAxisMaster => r.axisReg   (i).axisMaster,
  --    sAxisSlave  => maxisSlave  (i),
  --    -- Master Port
  --    mAxisClk    => clk,
  --    mAxisRst    => rst,
  --    mAxisMaster => axisMaster  (i),
  --    mAxisSlave  => axisSlave   (i) );
  axisMaster <= r.axisReg.axisMaster;
  maxisSlave <= axisSlave;
  
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
                  l1in, l1ina,
                  tout, dout, douten, rddata, maxisSlave ) is
    variable v : RegType;
    variable n : integer range 0 to 2*ROW_SIZE-1;
    variable i,j,k  : integer;
    variable imatch : integer;
    variable flush  : sl;
    variable skip   : sl;
    variable q      : AxisRegType;
    variable addr   : slv(CACHE_ADDR_LEN_C-1 downto 0);
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
      -- correct for stream header buffering first 16 bytes
      v.cache(i).eaddr  := v.cache(i).eaddr + toSlv(8/ILV_C,CACHE_ADDR_LEN_C);
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
        v.cache(i).baddr  := (v.wraddr & toSlv(k,IDX_BITS)) + toSlv(imatch,CACHE_ADDR_LEN_C);
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
    q := v.axisReg;
    i := conv_integer(q.ireading);

    v.free := resize(r.rdtail - r.wraddr,r.free'length);
      
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
        v.rdtail := r.wraddr-1;
      else
        v.rdtail := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
      end if;

      if (r.cache(i).state = CLOSED_S) then
--          and r.cache(i).mapd = DONE_M) then
        case r.cache(i).trigd is
          when WAIT_T   => null;
          when REJECT_T =>
            v.cache(i) := CACHE_INIT_C;
            q.ireading := q.ireading+1;
          when ACCEPT_T =>
            --
            --  Prepare reading from recorded data RAM
            --
            q.rdaddr := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
            --
            --  Form header word
            --
            q.buff(IDX_BITS+1 downto 0) := (others=>'0');
            q.buff(30 downto IDX_BITS+2) := 
              resize(r.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) -
                     r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) + 1,
                     29-IDX_BITS);  -- extent

            addr := r.cache(i).eaddr + toSlv(16/ILV_C,CACHE_ADDR_LEN_C);
            q.buff(31) := r.cache(i).ovflow;
            k := ILV_C*conv_integer(r.cache(i).baddr(IDX_BITS-1 downto 0));
            q.buff( 39 downto  32) := toSlv(k,8);         -- boff
            q.buff( 47 downto  40) := toSlv(ILV_C*(ROW_SIZE-conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0))),8);  -- eoff
            q.buff( 55 downto  48) := toSlv(i,8);         -- buffer
            q.buff( 63 downto  56) := toSlv(ALG_ID_G,8);  -- stream
            q.buff( 95 downto  64) := resize(r.cache(i).toffs,32);
            q.buff(111 downto  96) := resize(r.cache(i).baddr,16);
            q.buff(127 downto 112) := resize(r.cache(i).eaddr,16);
            v.cache(i).state := READING_S;
            skip := r.cache(i).skip;
            if skip = '1' then
              v.cache(i) := CACHE_INIT_C;
              q.ireading := q.ireading+1;
            end if;
          when others => null;
        end case;
      elsif r.cache(i).state = READING_S then
        --
        --  Continue streaming data from RAM
        --
        q.axisMaster.tValid := '1';
        q.axisMaster.tData(q.buff'range) := q.buff;
        q.axisMaster.tData(rddata'left downto q.buff'length) := rddata(rddata'left-q.buff'length downto 0);
        q.buff   := rddata(rddata'left downto rddata'length-q.buff'length);
        q.axisMaster.tKeep := genTKeep(64);
        if q.rdaddr = r.cache(i).eaddr(q.rdaddr'left+IDX_BITS downto IDX_BITS) then
          q.axisMaster.tLast := '1';
          v.cache(i) := CACHE_INIT_C;
          q.ireading := q.ireading+1;
        end if;
        q.rdaddr := q.rdaddr+1;
      end if;

      v.axisReg := q;
    end if;

    -- skipped buffers are causing this to fire
    if conv_integer(r.free) < 4 and false then
      --  Deadtime failed
      --  Close all open caches/gates and flag them
      v.wrfull := '0';
      v.wrword := (others=>'0');
      for i in 0 to 15 loop
        if r.cache(i).state = OPEN_S then
          v.cache(i).state := CLOSED_S;
--          v.cache(i).mapd  := DONE_M;
          v.cache(i).baddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).eaddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).ovflow := '1';
        end if;
      end loop;
    end if;
    
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

  GEN_RAW : if ALGORITHM_G = "RAW" generate
    U_FEX : entity work.hsd_raw_ilv
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x0_V                => din(0),
                 x1_V                => din(1),
                 x2_V                => din(2),
                 x3_V                => din(3),
                 x4_V                => din(4),
                 x5_V                => din(5),
                 x6_V                => din(6),
                 x7_V                => din(7),
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
    
  GEN_THR : if ALGORITHM_G = "THR" generate
    U_FEX : entity work.hsd_thr_ilv
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x0_V                => din(0),
                 x1_V                => din(1),
                 x2_V                => din(2),
                 x3_V                => din(3),
                 x4_V                => din(4),
                 x5_V                => din(5),
                 x6_V                => din(6),
                 x7_V                => din(7),
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

  GEN_NAT : if ALGORITHM_G = "NAT" generate
    GEN_DI_I : for i in 0 to ROW_SIZE-1 generate
      GEN_DI_J : for j in 0 to ILV_C-1 generate
        idin(i*ILV_C+j) <= din(i)(j*11+10 downto j*11);
      end generate;
    end generate;
    GEN_DO_I : for i in 0 to ROW_SIZE generate
      GEN_DO_J : for j in 0 to ILV_C-1 generate
        dout(i)(j*16+15 downto j*16) <= idout(i*ILV_C+j);
      end generate;
    end generate;

    U_FEX : entity work.hsd_thr_ilv_native
      generic map ( ILV_G => ILV_C,
                    BASELINE => ("01" & toSlv(0,AdcWord'length-2)) )
      port map ( ap_clk          => clk,
                 ap_rst_n        => rstn,
                 sync            => configSync,
                 x               => idin,
                 tin             => r.tin,
                 y               => idout,
                 tout            => tout,
                 yv              => douten,
                 axilReadMaster  => axilReadMaster,
                 axilReadSlave   => axilReadSlave,
                 axilWriteMaster => axilWriteMaster,
                 axilWriteSlave  => axilWriteSlave );
  end generate;
  
end mapping;

