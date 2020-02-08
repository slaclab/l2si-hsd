-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcRamp.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-09-30
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
use work.QuadAdcPkg.all;
use work.FmcPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AdcRamp is
  generic( NCHAN_G : integer := 4 );
  port ( phyClk      : in  sl;
         dmaClk      : out sl;
         ready       : in  sl;
         adcOut      : out AdcDataArray(NCHAN_G-1 downto 0);
         trigSel     : in  sl;
         trigOut     : out slv(ROW_SIZE-1 downto 0)
    );
end AdcRamp;

architecture behavior of AdcRamp is
  signal adcClk           : sl;
  signal adcI,adcO        : AdcDataArray (NCHAN_G-1 downto 0);

  signal trigIn  : slv(ROW_SIZE-1 downto 0) := (others=>'0');
   
begin

  dmaClk  <= adcClk;
  adcOut  <= adcO;
  trigOut <= trigIn;

   process(phyClk) is
     variable v : integer := 0;
     constant CLK_RATIO : integer := ROW_SIZE;
   begin
     if rising_edge(phyClk) then
       v := v+1;
       if (v = CLK_RATIO/2) then
         adcClk <= '0';
       elsif (v = CLK_RATIO) then
         adcClk <= '1';
         v := 0;
       end if;
     end if;
   end process;
  
  process (phyClk) is
     variable s : slv(AdcWord'range) := (others=>'0');
     variable d : slv(2 downto 0) := (others=>'0');
   begin
     if rising_edge(phyClk) then
       for ch in 0 to NCHAN_G-1 loop
         adcI(ch).data(ROW_SIZE-1) <= s;
         adcI(ch).data(ROW_SIZE-2 downto 0) <= adcI(ch).data(ROW_SIZE-1 downto 1);
       end loop;

       trigIn <= d(0) & trigIn(ROW_SIZE-1 downto 1);
       d := trigSel & d(2 downto 1);
       --
       --  Ramp the signal (let it slip by one each cycle)
       --
       s := s+1;
       --if s = toSlv(1047,11) then
       --  s := s+1;
       --end if;

     end if;
   end process;

   process (adcClk) is
   begin
     if rising_edge(adcClk) then
       adcO <= adcI;
     end if;
   end process;
     
end behavior;
     
