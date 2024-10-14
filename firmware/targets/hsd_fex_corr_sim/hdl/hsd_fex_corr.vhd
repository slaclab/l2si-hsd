library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use work.FmcPkg.all;

entity hsd_fex_corr is
generic (
  NUMWORDS_G : integer := 40;
  NUMACCUM_G : integer range 3 to 12 := 12;  -- 2s exponent of samples in baseline sums
  BASELINE_G : slv(14 downto 0) := toSlv(2**14,15) );
port (
  rst       : in  std_logic;
  clk       : in  std_logic;
  start     : in  std_logic; -- accum baseline correction
  adcIn     : in  AdcWordArray(NUMWORDS_G-1 downto 0);
  adcOut    : out Slv15Array(NUMWORDS_G-1 downto 0) );
end;  

architecture behav of hsd_fex_corr is

  type RegType is record
    adcOut  : Slv15Array(NUMWORDS_G-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    adcOut  => (others=>BASELINE_G) );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

begin
  
  adcOut <= r.adcOut;

  comb : process ( rst, r, adcIn ) is
    variable v : RegType;
    variable k : integer;
  begin
    v := r;

    k := 0;
    for i in 0 to 9 loop
      for j in 0 to 3 loop
        v.adcOut(k) := adcIn(k) & "000";
        k := k + 1;
      end loop;
    end loop;
    
    if rst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process seq;

end behav;
