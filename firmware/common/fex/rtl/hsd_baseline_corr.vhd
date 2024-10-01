library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use work.FmcPkg.all;

entity hsd_baseline_corr is
  generic (
    TPD_G      : time := 1 ns;
    NUMWORDS_G : integer := 40;
    MAXACCUM_G : integer := 12 );
  port (
    rst       : in  std_logic;
    clk       : in  std_logic;
    accShift  : in  slv( 3 downto 0) := toSlv(12,4); -- 3 <= accShift <= 12
    baseline  : in  slv(14 downto 0) := toSlv(2**14,15);
    tIn       : in  Slv2Array   (NUMWORDS_G/4-1 downto 0);
    adcIn     : in  AdcWordArray(NUMWORDS_G-1 downto 0);
    tOut      : out Slv2Array   (NUMWORDS_G/4-1 downto 0);
    adcOut    : out Slv15Array  (NUMWORDS_G-1 downto 0) );
end;  

architecture behav of hsd_baseline_corr is

  constant MAXACCUM_C : integer := MAXACCUM_G;
  
  type StateType is (IDLE_S, ACCUM_S);
  
  type RegType is record
    tOut    : Slv2Array (NUMWORDS_G/4-1 downto 0);
    adcOut  : Slv15Array(NUMWORDS_G-1 downto 0);
    adcSum  : Slv15Array(3 downto 0);
    adcRun  : Slv24Array(3 downto 0);
    adcCorr : Slv15Array(3 downto 0);
    addr    : slv(MAXACCUM_C-4 downto 0);
    wraddr  : slv(MAXACCUM_C-4 downto 0);
    rdaddr  : slv(MAXACCUM_C-4 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    tOut    => (others=>"00"),
    adcOut  => (others=>toSlv(0,15)),
    adcSum  => (others=>toSlv(0,15)),
    adcRun  => (others=>toSlv(0,24)),
    adcCorr => (others=>toSlv(2**14,15)),
    addr    => toSlv(0,MAXACCUM_C-3),
    wraddr  => toSlv(0,MAXACCUM_C-3),
    rdaddr  => toSlv(1,MAXACCUM_C-3) );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;
    
  --  Running sum signals
  signal din  : slv(59 downto 0);
  signal dout : slv(59 downto 0);
  signal adcSumO : Slv15Array(3 downto 0);
  
begin

  tOut   <= r.tOut;
  adcOut <= r.adcOut;

  U_RAM : entity surf.SimpleDualPortRam
    generic map (
      DATA_WIDTH_G => 4*(12+3),
      ADDR_WIDTH_G => MAXACCUM_C-3 )
    port map (
      clka     => clk,
      wea      => '1',
      addra    => r.wraddr,
      dina     => din,
      clkb     => clk,
      rstb     => rst,
      addrb    => r.rdaddr,
      doutb    => dout );

  din        <= r.adcSum(3) & r.adcSum(2) & r.adcSum(1) & r.adcSum(0);
  adcSumO(0) <= dout(14 downto 0);
  adcSumO(1) <= dout(29 downto 15);
  adcSumO(2) <= dout(44 downto 30);
  adcSumO(3) <= dout(59 downto 45);

  comb : process ( rst, r, adcIn, tIn, adcSumO, accShift, baseline ) is
    variable v : RegType;
    variable k : integer;
    variable n : integer;
    variable q : slv(15 downto 0);
    variable start : sl;
    constant OUT_OF_RANGE : slv(14 downto 0) := (others=>'1');
  begin
    v := r;

    v.tOut := tIn;
    
    start := '0';
    for j in 0 to 9 loop
      if tIn(j)(0)='1' then
        start := '1';
      end if;
    end loop;
    
    if start = '1' then
      for i in 0 to 3 loop
        v.adcCorr(i) := r.adcRun(i)(14+n downto n);
      end loop;
    end if;
    
    k := 0;
    for j in 0 to 9 loop
      for i in 0 to 3 loop
        q := (others=>'0');
        q(14 downto 3) := adcIn(k)(11 downto 0); -- f(11:3)
        q := q + resize(baseline,16) - resize(v.adcCorr(i),16);
        if q(15) = '1' then -- underflow/overflow
          v.adcOut(k) := OUT_OF_RANGE;
        else
          v.adcOut(k) := resize(q,15);
        end if;
        k := k+1;
      end loop;
    end loop;

    k := 0;
    v.adcSum := (others=>toSlv(0,15));
    --for j in 0 to 9 loop  -- 10 does not give us powers of 2!
    --  Another possibility is to sum all 10 and keep a factor of 10 in the output
    for j in 0 to 7 loop
      for i in 0 to 3 loop
        v.adcSum(i) := v.adcSum(i) + adcIn(k);
        k           := k+1;
      end loop;
    end loop;

    for i in 0 to 3 loop
      v.adcRun(i) := r.adcRun(i) + r.adcSum(i) - adcSumO(i);
    end loop;

    v.addr   := r.addr+1;
    n := conv_integer(accShift)-3;
    v.wraddr := resize(r.addr(n-1 downto 0),MAXACCUM_C-3);
    v.rdaddr := resize(v.addr(n-1 downto 0),MAXACCUM_C-3);
    -- if r.rdaddr(n-1 downto 0) = toSlv(-1,n) then
    --   v.rdaddr := (others=>'0');
    -- end if;
    
    if rst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= r_in after TPD_G;
    end if;
  end process seq;

end behav;
