-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcDataFromFile.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2024-09-30
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

entity AdcDataFromFile is
  generic ( FILENAME_G : string := "default.xtc";
            NUMWORDS_G : integer := 40 );
  port ( rst         : in  sl;
         clk         : in  sl;
         adcWords    : out AdcWordArray(NUMWORDS_G-1 downto 0);
         start       : out sl );
end AdcDataFromFile;

architecture behavior of AdcDataFromFile is

  signal str : string(1 to 4*NUMWORDS_G+2);
  
begin

  process is
    function Slv4FromChar(v : in character) return slv is
      variable result : slv(3 downto 0) := x"0";
    begin
      case(v) is
        when '0' => result := x"0";
        when '1' => result := x"1";
        when '2' => result := x"2";
        when '3' => result := x"3";
        when '4' => result := x"4";
        when '5' => result := x"5";
        when '6' => result := x"6";
        when '7' => result := x"7";
        when '8' => result := x"8";
        when '9' => result := x"9";
        when 'a' => result := x"a";
        when 'b' => result := x"b";
        when 'c' => result := x"c";
        when 'd' => result := x"d";
        when 'e' => result := x"e";
        when 'f' => result := x"f";
        when others => null;
      end case;
      return result;
    end function;

    function ArrayFromString(v : string) return AdcWordArray is
      variable result : AdcWordArray(NUMWORDS_G-1 downto 0);
      variable k : integer;
    begin
      k := 1;
      for i in 0 to NUMWORDS_G-1 loop
        k := k+1; -- skip over space
        for j in 2 downto 0 loop
          result(i)(j*4+3 downto j*4) := Slv4FromChar(v(k));
          k := k+1;
        end loop;
      end loop;
      return result;
    end function;

    file results : text;
    variable iline : line;
    variable istr : string(str'range);
  begin
    file_open(results, FILENAME_G, read_mode);
    while not endfile(results) loop
      wait until falling_edge(clk);
      readline(results, iline);
      read(iline, istr);        
      adcWords  <= ArrayFromString(istr(1 to 4*NUMWORDS_G));
      str       <= istr;
      if istr(istr'right)='0' then
        start <= '0';
      else
        start <= '1';
      end if;
      
      if rst = '1' then
        adcWords  <= (others=>x"800");
        start     <= '0';
      end if;
    end loop;
    file_close(results);
  end process;

end behavior;
