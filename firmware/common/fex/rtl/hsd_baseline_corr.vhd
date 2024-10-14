-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Baseline correction for ADC data stream
--   Corrects data by subtracting an averaged baseline sampled from data
--  preceding the trigger.  Assumes input data is 12-bit, output data is 15-bit
--  with 4-bits fractional.  Out-of-range data is signified by the 'oor' signal.
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

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
    accShift  : in  slv( 3 downto 0) := toSlv(12,4); -- 4 <= accShift <= 12
    baseline  : in  slv(14 downto 0) := toSlv(2**14,15);
    tIn       : in  Slv2Array   (NUMWORDS_G/4-1 downto 0);
    adcIn     : in  AdcWordArray(NUMWORDS_G-1 downto 0);
    tOut      : out Slv2Array   (NUMWORDS_G/4-1 downto 0);
    adcOut    : out Slv15Array  (NUMWORDS_G-1 downto 0);
    oor       : out sl );
end;  

architecture behav of hsd_baseline_corr is

  constant MAXACCUM_C : integer := MAXACCUM_G;
  constant FRACBITS_C : integer := 4;
  
  type StateType is (IDLE_S, ACCUM_S);
  
  type RegType is record
    init    : sl;
    oor     : sl;
    tOut    : Slv2Array (NUMWORDS_G/4-1 downto 0);
    tNew    : Slv2Array (NUMWORDS_G/4-1 downto 0);
    adcOut  : Slv15Array(NUMWORDS_G-1 downto 0);
    adcNew  : Slv15Array(NUMWORDS_G-1 downto 0);
    adcSum  : Slv15Array(3 downto 0); -- 12-bit input + 3-bits summing (to 8)
    adcRun  : Slv24Array(3 downto 0); -- 12-bit input + MAXACCUM_C bits summing
    adcCorr : Slv16Array(3 downto 0); -- 12-bit input + 4-bits fractional
    -- RAM for sums of 8 samples (one clk)
    addr    : slv(MAXACCUM_C-4 downto 0);
    wraddr  : slv(MAXACCUM_C-4 downto 0);
    rdaddr  : slv(MAXACCUM_C-4 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    init    => '1',
    oor     => '1',
    tOut    => (others=>"00"),
    tNew    => (others=>"00"),
    adcOut  => (others=>toSlv(0,15)),
    adcNew  => (others=>toSlv(0,15)),
    adcSum  => (others=>toSlv(0,15)),
    adcRun  => (others=>toSlv(0,24)),
    adcCorr => (others=>toSlv(2**15,16)),
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
  oor    <= r.oor;
  
  U_RAM : entity surf.SimpleDualPortRam
    generic map (
      DATA_WIDTH_G => 4*15,
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
    constant CORR_SHIFT   : slv(15 downto 0) := toSlv(16384,16);
  begin
    v := r;

    v.oor  := '0';
    v.tNew := tIn;
    
    start := '0';
    for j in 0 to 9 loop
      if tIn(j)(0)='1' then
        start := '1';
      end if;
    end loop;
    
    if start = '1' then
      -- latch the correction
      n := conv_integer(accShift)-FRACBITS_C;
      for i in 0 to 3 loop
        v.adcCorr(i) := r.adcRun(i)(15+n downto n);
      end loop;
    end if;
    
    k := 0;
    for j in 0 to 9 loop
      for i in 0 to 3 loop
        q := resize(adcIn(k) & toSlv(0,FRACBITS_C),16);
        q := q + resize(baseline,16) - resize(v.adcCorr(i),16);
        v.adcNew(k) := q(14 downto 0);
        if q(15) = '1' then -- underflow/overflow
          v.oor := '1';
          --v.adcNew(k) := OUT_OF_RANGE;
        end if;
        k := k+1;
      end loop;
    end loop;

    --
    --  Prepend the correction values.
    --
    v.adcOut := r.adcNew;
    v.tOut   := r.tNew;
    k := 0;
    for j in 0 to 9 loop
      for i in 0 to 3 loop
        if r.tNew(j)(0)='1' then
          --  Map baseline constants to 15-bits: expect value ~2<<15 +- a small number
          --  Subtract 2<<14 to bring it within 15-bits
          q := r.adcCorr(i);
          q := q - CORR_SHIFT;
          v.adcOut(k) := resize(q,15);
          if q(15) = '1' then
            v.oor := '1';
          end if;
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

    --  block ram doesn't reinitialize on reset, so set this flag to qualify
    --  when all entries have been written.
    n := conv_integer(accShift)-3;
    if uAnd(r.wraddr(n-1 downto 0))='1' then
      v.init := '0';
    end if;
    
    for i in 0 to 3 loop
      if r.init = '1' then
        v.adcRun(i) := r.adcRun(i) + r.adcSum(i);
      else
        v.adcRun(i) := r.adcRun(i) + r.adcSum(i) - adcSumO(i);
      end if;
    end loop;

    --  limit ram address to range of running sums
    v.addr   := r.addr+1;
    v.wraddr := resize(r.addr(n-1 downto 0),MAXACCUM_C-3);
    v.rdaddr := resize(v.addr(n-1 downto 0),MAXACCUM_C-3);

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
