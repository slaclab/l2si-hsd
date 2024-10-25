-----------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_corr_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2024-10-22
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

library work;
use work.FmcPkg.all;

entity hsd_fex_corr_sim is
end hsd_fex_corr_sim;

architecture top_level_app of hsd_fex_corr_sim is

  --  Number of ADC data samples passed on one clk cycle
  constant NUMWORDS_C : integer := 40;
  --constant NUMACCUM_C : integer := 12;
  constant NUMACCUM_C : integer := 6;
  constant BASELINE_C : slv(14 downto 0) := resize(x"6000",15);
  
  signal clk64g : sl;
  signal rst, rst160, clk160 : sl;
  signal startBase : sl;
  signal adcIn  : AdcWordArray(NUMWORDS_C-1 downto 0);
  signal adcOut, adcOut2 : Slv15Array  (NUMWORDS_C-1 downto 0);
  signal adcSerialIn  : AdcWord;
  signal adcSerialOut : slv(15 downto 0);
  signal tIn  : Slv2Array(NUMWORDS_C/4-1 downto 0) := (others=>"00");
  signal tOut : Slv2Array(NUMWORDS_C/4-1 downto 0);

begin

  -- generate a 6.4 GHz clock
  clk_p : process is
  begin
    clk64g <= '0';
    wait for 0.1 ns;
    clk64g <= '1';
    wait for 0.1 ns;
  end process clk_p;
  
  -- generate the 160 MHz clk used by the FPGA logic
  clk160_p : process is
  begin
    clk160 <= '0';
    for i in 0 to 19 loop
      wait until rising_edge(clk64g);
    end loop;
    clk160 <= '1';
    for i in 0 to 19 loop
      wait until rising_edge(clk64g);
    end loop;
  end process clk160_p;

  -- generate a reset at startup
  rst_p : process is
  begin
    rst <= '1';
    wait for 50 ns;
    rst <= '0';
    wait;
  end process rst_p;

  U_RST160 : entity surf.RstSync
    port map ( clk      => clk160,
               asyncRst => rst,
               syncRst  => rst160 );
      
  -- read the raw data from a file
  U_ADC_In : entity work.AdcDataFromFile
    generic map ( FILENAME_G => "adcin.dat",
                  NUMWORDS_G => NUMWORDS_C )
    port map ( rst      => rst160,
               clk      => clk160,
               adcWords => adcIn,
               start    => startBase );

  tIn(0)(0) <= startBase;
  
  U_CORR : entity work.hsd_baseline_corr
    port map ( rst       => rst160,
               clk       => clk160,
               accShift  => toSlv(NUMACCUM_C,4),
               baseline  => BASELINE_C,
               tIn       => tIn,
               adcIn     => adcIn,
               tOut      => tOut,
               adcOut    => adcOut,
               oor       => open );
  
  -- write the corrected data to a file
  U_ADC_Out : entity work.AdcDataToFile
    generic map ( FILENAME_G => "adcout.dat",
                  NUMWORDS_G => NUMWORDS_C )
    port map ( rst      => rst160,
               clk      => clk160,
               adcWords => adcOut,
               start    => startBase );

  --  this is just for display
  adc64g_p : process (clk64g) is
    variable adcDataIn  : AdcWordArray(NUMWORDS_C-1 downto 0) := (others=>x"000");
    variable adcDataOut : Slv15Array(NUMWORDS_C-1 downto 0) := (others=>toSlv(0,15));
    variable index : integer := 39;
  begin
    if rising_edge(clk64g) then
      if rst160 = '1' then
        adcSerialIn  <= x"000";
        adcSerialOut <= x"0000";
        index        := NUMWORDS_C-1;
        adcDataIn    := (others=>x"000");
        adcDataOut   := (others=>toSlv(0,15));
      else
        if index = NUMWORDS_C-1 then
          index      := 0;
          adcDataIn  := adcIn;
          adcDataOut := adcOut;
        end if;
        adcSerialIn  <= adcDataIn (index);
        adcSerialOut <= resize(adcDataOut(index),16);
        index := index + 1;
      end if;
    end if;
  end process adc64g_p;
  
end top_level_app;
