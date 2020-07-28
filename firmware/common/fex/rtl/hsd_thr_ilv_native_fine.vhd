library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use work.FmcPkg.all;
use work.QuadAdcPkg.all;

entity hsd_thr_ilv_native_fine is
generic (
    ILV_G                    : INTEGER := 4;
    BASELINE                 : AdcWord);
port (
    ap_clk   : IN STD_LOGIC;
    ap_rst_n : IN STD_LOGIC;
    sync     : IN  STD_LOGIC;
    x        : in  AdcWordArray(ILV_G*ROW_SIZE-1 downto 0);
    tin      : in  Slv2Array   (      ROW_SIZE-1 downto 0);
    y        : out Slv16Array  (ILV_G*ROW_SIZE+ILV_G-1 downto 0);
    tout     : out Slv2Array   (      ROW_SIZE   downto 0);
    yv       : out slv         (      ROW_IDXB-1 downto 0);
    axilReadMaster  : in  AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster : in  AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );

end;

architecture behav of hsd_thr_ilv_native_fine is

  type FillState is ( KEEP_NONE, KEEP_MID, KEEP_HEAD, KEEP_TAIL, KEEP_ALL );

  type KeepType is record
    state      : FillState;
    first      : integer range 0 to ROW_SIZE;
    last       : integer range 0 to ROW_SIZE;
  end record;

  constant KEEP_INIT_C : KeepType := (
    state      => KEEP_NONE,
    first      => 0,
    last       => 0 );

  type KeepArray is array(natural range<>) of KeepType;

  constant KEEP_ROWS_C : integer := 3;
  constant CBITS_C : integer := bitSize(KEEP_ROWS_C*ROW_SIZE);
  constant ADDRB_C : integer := bitSize(2*KEEP_ROWS_C+3);

  type RegType is record
    xlo        : AdcWord;           -- low threshold
    xhi        : AdcWord;           -- high threshold
    tpre       : slv(CBITS_C-1 downto 0);  -- number of super samples to readout before crossing
    tpost      : slv(CBITS_C-1 downto 0);  -- number of super samples to readout after crossing
    tpreRows   : integer range 0 to KEEP_ROWS_C;
    tpostRows  : integer range 0 to KEEP_ROWS_C;
    tpreCol    : integer range 0 to ROW_SIZE-1;
    tpostCol   : integer range 1 to ROW_SIZE;
    sync       : sl;
    
    count      : slv(12 downto 0);
    count_last : slv(12 downto 0);
    nopen      : slv(4 downto 0);   -- number of readout streams open
    lskip      : sl;
    tskip      : slv( 1 downto 0);
    
    waddr      : slv(ADDRB_C-1 downto 0);  -- index into row buffer
    raddr      : slv(ADDRB_C-1 downto 0);
    ikeepf     : integer range 0 to ROW_SIZE;
    ikeepl     : integer range 0 to ROW_SIZE;
    kupdate    : sl;
    irowf      : integer range 0 to 2*KEEP_ROWS_C;
    irowl      : integer range 0 to 2*KEEP_ROWS_C;
    icolf      : integer range 0 to ROW_SIZE-1;
    icoll      : integer range 0 to ROW_SIZE-1;
    
    akeep      : KeepArray(2*KEEP_ROWS_C downto 0);  -- super-samples to keep
    
    y          : Slv16Array(ILV_G*ROW_SIZE+ILV_G-1 downto 0); -- readout
    t          : Slv2Array (      ROW_SIZE downto 0);
    yv         : slv       (      ROW_IDXB-1 downto 0);  -- number of valid
                                                         -- readout samples
    
    readSlave  : AxiLiteReadSlaveType;
    writeSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    xlo        => BASELINE,
    xhi        => BASELINE,
    tpre       => toSlv(  1,CBITS_C),
    tpost      => toSlv(  1,CBITS_C),
    tpreRows   => 1,
    tpostRows  => 1,
    tpreCol    => 1,
    tpostCol   => 1,
    sync       => '1',
    
    count      => (others=>'0'),
    count_last => (others=>'0'),
    nopen      => (others=>'0'),
    lskip      => '0',
    tskip      => "00",
    
    waddr      => (others=>'0'),
    raddr      => (others=>'0'),
    ikeepf     => ROW_SIZE,
    ikeepl     => ROW_SIZE,
    kupdate    => '0',
    irowf      => 0,
    irowl      => 0,
    icolf      => 0,
    icoll      => 0,
    akeep      => (others=>KEEP_INIT_C),
    
    y          => (others=>(others=>'0')),
    t          => (others=>(others=>'0')),
    yv         => (others=>'0'),
    readSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    writeSlave => AXI_LITE_WRITE_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal xsave : AdcWordArray(ILV_G*ROW_SIZE-1 downto 0);
  signal tsave : Slv2Array   (      ROW_SIZE-1 downto 0);

  constant ANY_SKIP_G : boolean := true;
  
begin

  axilWriteSlave <= r.writeSlave;
  axilReadSlave  <= r.readSlave;

  --
  --  Buffer of sample and trigger data
  --    Necessary for prepending samples when a threshold crossing
  --    is found within the trigger window.
  --
  GEN_RAM : for i in 0 to ROW_SIZE-1 generate
    U_RAMB : block is
      signal din,dout : slv(ILV_G*AdcWord'length+1 downto 0);
    begin
      GEN_DIN : for j in 0 to ILV_G-1 generate
        din((j+1)*AdcWord'length-1 downto j*AdcWord'length) <= x(i*ILV_G+j);
        xsave(i*ILV_G+j) <= dout((j+1)*AdcWord'length-1 downto j*AdcWord'length);
      end generate;
      din(ILV_G*AdcWord'length+1 downto ILV_G*AdcWord'length) <= tin(i);
      tsave(i) <= dout(ILV_G*AdcWord'length+1 downto ILV_G*AdcWord'length);
      
      U_RAM : entity surf.SimpleDualPortRam
        generic map ( DATA_WIDTH_G => ILV_G*AdcWord'length+2,
                      ADDR_WIDTH_G => r.waddr'length )
        port map ( clka                => ap_clk,
                   wea                 => '1',
                   addra               => r.waddr,
                   dina                => din,
                   clkb                => ap_clk,
                   addrb               => r.raddr,
                   doutb               => dout );
    end block;
  end generate;
  
  comb : process ( ap_rst_n, r, x, tin, xsave, tsave,
                   axilWriteMaster, axilReadMaster ) is
    variable v      : RegType;
    variable ep     : AxiLiteEndPointType;
    variable tsum   : slv(1 downto 0);
    variable iopen  : integer;
    variable lout   : sl;
    variable lkeep  : sl;
    variable ikeepl : integer;
    variable ikeepf : integer;
    variable i,k    : integer;
    variable tpre   : integer;
    variable tpost  : integer;
    variable dcount : slv(12 downto 0);
    constant ILVB   : integer := bitSize(ILV_G-1);
  begin
    v := r;

    -- AxiLite accesses
    axiSlaveWaitTxn( ep,
                     axilWriteMaster, axilReadMaster,
                     v.writeSlave, v.readSlave );

    v.readSlave.rdata := (others=>'0');
      
    axiSlaveRegister ( ep, x"10", 0, v.xlo   );
    axiSlaveRegister ( ep, x"18", 0, v.xhi   );
    axiSlaveRegister ( ep, x"20", 0, v.tpre  );  -- samples before gate opens/thr
                                                 -- crossing
    axiSlaveRegister ( ep, x"28", 0, v.tpost );  -- samples after gate
                                                 -- closes/thr crossing

    tpre  := conv_integer(r.tpre);
    tpost := conv_integer(r.tpost);
    v.tpreRows  := (tpre +ROW_SIZE-1)/ROW_SIZE;
    v.tpostRows := (tpost+ROW_SIZE-1)/ROW_SIZE;
    v.tpreCol   := tpre  mod ROW_SIZE;               -- 0 .. ROW_SIZE-1
    v.tpostCol  := ROW_SIZE - (tpost mod ROW_SIZE);  -- 1 .. ROW_SIZE
    
    v.sync := '0';
    axiWrDetect(ep, x"20", v.sync);
    axiWrDetect(ep, x"28", v.sync);
    
    axiSlaveDefault( ep, v.writeSlave, v.readSlave );

    --
    --  The keep mask is in units of super-samples.
    --  It shifts by ROW_SIZE each clk.
    --  Output will only sparsify on empty space at
    --  the beginning and end of a row (reduce combinatorics).
    --  Maybe keep mask is just the first and last sample in a row. (,]
    --

    --  first and last threshold crossing in the row
    ikeepl := ROW_SIZE;
    for i in 0 to ROW_SIZE-1 loop
      for j in 0 to ILV_G-1 loop
        k := 4*i+j;
        if ((x(k) < r.xlo) or (x(k) > r.xhi) or (tin(i) /= "00")) then
          ikeepl := i;
        end if;
      end loop;
    end loop;
    v.ikeepl := ikeepl;
    
    ikeepf := ROW_SIZE;
    for i in ROW_SIZE-1 downto 0 loop
      for j in 0 to ILV_G-1 loop
        k := 4*i+j;
        if ((x(k) < r.xlo) or (x(k) > r.xhi) or (tin(i) /= "00")) then
          ikeepf := i;
        end if;
      end loop;
    end loop;
    v.ikeepf := ikeepf;

    v.kupdate := '0';
    if r.ikeepf < ROW_SIZE then  -- crossing found
      v.kupdate := '1';
      if r.ikeepf < r.tpreCol then
        v.irowf := 0;
        v.icolf := ROW_SIZE-r.tpreCol+r.ikeepf;
      else
        v.irowf := 1;
        v.icolf := r.ikeepf-r.tpreCol;
      end if;
      if r.ikeepl < r.tpostCol then
        v.irowl := r.tpreRows+r.tpostRows-1;
        v.icoll := ROW_SIZE-r.tpostCol+r.ikeepl;
      else
        v.irowl := r.tpreRows+r.tpostRows;
        v.icoll := r.ikeepl - r.tpostCol;
      end if;
    end if;
    
    v.akeep := KEEP_INIT_C & r.akeep(r.akeep'left downto 1);

    if r.kupdate = '1' then  -- crossing found
      --  enumerate all combinations
      for irow in 0 to 2*KEEP_ROWS_C loop
        if irow = r.irowf then
          if v.akeep(irow).state = KEEP_NONE then
              if r.icoll = ROW_SIZE-1 or r.irowl > irow then
                if r.icolf = 0 then
                  v.akeep(irow).state := KEEP_ALL;
                  v.akeep(irow).first := 0;
                  v.akeep(irow).last  := ROW_SIZE-1;
                else
                  v.akeep(irow).state := KEEP_TAIL;
                  v.akeep(irow).first := r.icolf;
                  v.akeep(irow).last  := ROW_SIZE-1;
                end if;
              elsif r.icolf = 0 then
                v.akeep(irow).state := KEEP_HEAD;
                v.akeep(irow).first := 0;
                v.akeep(irow).last  := r.icoll;
              else
                v.akeep(irow).state := KEEP_MID;
                v.akeep(irow).first := r.icolf;
                v.akeep(irow).last  := r.icoll;
              end if;
          elsif v.akeep(irow).state = KEEP_HEAD then
              if r.icoll = ROW_SIZE-1 or r.irowl > irow then
                v.akeep(irow).state := KEEP_ALL;
                v.akeep(irow).first := 0;
                v.akeep(irow).last  := ROW_SIZE-1;
              else
                v.akeep(irow).last  := r.icoll;
              end if;
          elsif v.akeep(irow).state = KEEP_MID then
              if r.icoll = ROW_SIZE-1 or r.irowl > irow then
                v.akeep(irow).state := KEEP_TAIL;
                v.akeep(irow).last  := ROW_SIZE-1;
              else
                v.akeep(irow).last  := r.icoll;
              end if;
          end if;
        elsif irow = r.irowl then
          if v.akeep(irow).state = KEEP_NONE or
             v.akeep(irow).state = KEEP_HEAD then
             if r.icoll = ROW_SIZE-1 then
                v.akeep(irow).state := KEEP_ALL;
                v.akeep(irow).first := 0;
                v.akeep(irow).last  := ROW_SIZE-1;
              else
                v.akeep(irow).state := KEEP_HEAD;
                v.akeep(irow).first := 0;
                v.akeep(irow).last  := r.icoll;
              end if;
          end if;
        elsif irow > r.irowf and irow < r.irowl then
          v.akeep(irow).state := KEEP_ALL;
          v.akeep(irow).first := 0;
          v.akeep(irow).last  := ROW_SIZE-1;
        end if;              
      end loop;
    end if;

    -- default response
    for i in 0 to ILV_G*ROW_SIZE-1 loop
      v.y(i) := resize(xsave(i),16);
    end loop;
    for i in 0 to ILV_G-1 loop
      v.y(i+ILV_G*ROW_SIZE) := x"8000";
    end loop;
    v.t     := "00" & tsave;

    -- check for trigger window opening/closing
    --   only one may open/close within a row, but multiple
    --   windows may remain open
    tsum := "00";
    iopen := ROW_SIZE-1;
    for i in ROW_SIZE-1 downto 0 loop
      tsum := tsum or tsave(i);
      if tsave(i) /= "00" then
        iopen := i;
      end if;
    end loop;

    --  samples/ILV_G since last readout
    dcount := r.count - r.count_last;

    -- window is open and this row needs readout
    if (((r.nopen/=0) or (tsum/="00")) and r.akeep(0).state/=KEEP_NONE) then
      if (r.lskip = '1' or
          r.akeep(0).state = KEEP_MID or
          r.akeep(0).state = KEEP_TAIL) then --  samples have been skipped
        dcount := dcount + r.akeep(0).first;
        -- skip to the first position
        v.y(0) := '1' & resize(dcount-1,15-ILVB) & toSlv(0,ILVB);
        for i in 1 to ILV_G-1 loop
          v.y(i) := '1' & toSlv(0,15);
        end loop;
        v.t(0)  := r.tskip;
        v.tskip := "00";
        -- and readout the row
        for i in 0 to ROW_SIZE-1 loop
          if i >= r.akeep(0).first then
            k := i-r.akeep(0).first;
            for j in 0 to ILV_G-1 loop
              v.y((k+1)*ILV_G+j) := resize(xsave(i*ILV_G+j),16);
            end loop;
            v.t(k+1) := tsave(i);
          end if;
        end loop;
        v.yv   := toSlv(r.akeep(0).last-r.akeep(0).first+2,ROW_IDXB);
      else  -- no skip needed
        for i in 0 to ROW_SIZE-1 loop
          if i >= r.akeep(0).first then
            k := i-r.akeep(0).first;
            for j in 0 to ILV_G-1 loop
              v.y((k)*ILV_G+j) := resize(xsave(i*ILV_G+j),16);
            end loop;
            v.t(k) := tsave(i);
          end if;
        end loop;
        v.yv   := toSlv(r.akeep(0).last-r.akeep(0).first+1,ROW_IDXB);
      end if;
      v.count_last := r.count+r.akeep(0).last;
      if r.akeep(0).last = ROW_SIZE-1 then
        v.lskip      := '0';
      else
        v.lskip      := '1';
      end if;
    -- a window opened/closed or enough samples skipped, but no readout
    -- insert a skip to the sample before the trigger
    elsif (tsum/="00" or dcount(dcount'left) ='1') then
      -- skip to the opening position
      v.y(0) := '1' & resize(dcount+iopen-1,15-ILVB) & toSlv(0,ILVB);
      for i in 1 to ILV_G-1 loop
        v.y(i) := '1' & toSlv(0,15);
      end loop;
      v.t(0)  := r.tskip;
      v.tskip := tsum;  -- save trigger bits for next readout/skip
      if tsum/="00" or ANY_SKIP_G then
        v.yv    := toSlv(1,ROW_IDXB);
      else
        v.yv    := toSlv(0,ROW_IDXB);
      end if;
      v.count_last := r.count + iopen-1;
      v.lskip := '1';
    -- no readout
    else
      v.yv    := toSlv(0,ROW_IDXB);
      v.lskip := '1';
    end if;

    if r.sync = '1' then
      v.waddr := toSlv(r.tpreRows+2,r.waddr'length);
      v.raddr := (others=>'0');
    else
      v.waddr := r.waddr + 1;
      v.raddr := r.raddr + 1;
    end if;
    
    if tsum = "01" then
      v.nopen := r.nopen+1;
    elsif tsum = "10" then
      v.nopen := r.nopen-1;
    end if;

    v.count := r.count + ROW_SIZE;

    y    <= r.y;
    yv   <= r.yv;
    tout <= r.t;
    
    if ap_rst_n = '0' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( ap_clk ) is
  begin
    if rising_edge(ap_clk) then
      r <= r_in;
    end if;
  end process seq;

end behav;
