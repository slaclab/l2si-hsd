-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DualAdcTrigger.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-03-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
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

library l2si_core;
use l2si_core.L2SiPkg.all;

use work.FmcPkg.all;

entity DualAdcTrigger is
  generic ( NCHAN_C : integer := 1 );
  port ( triggerClk  : in  sl;
         triggerRst  : in  sl;
         triggerData : in TriggerEventDataType;
         --
         clk         : in  sl;
         rst         : in  sl;
         afullIn     : in  slv(NCHAN_C-1 downto 0);
         enable      : in  slv(NCHAN_C-1 downto 0);
         afullOut    : out sl;
         afullCnt    : out slv(31 downto 0);
         ql1in       : out sl;
         ql1ina      : out sl;
         clear       : out sl;
         start       : out sl );
end DualAdcTrigger;

architecture mapping of DualAdcTrigger is

  type TrigRegType is record
    l0inacc : sl;
    l1inrej : sl;
    l1inacc : sl;
  end record;

  constant TRIG_REG_INIT_C : TrigRegType := (
    l0inacc => '0',
    l1inrej => '0',
    l1inacc => '0' );

  signal t    : TrigRegType := TRIG_REG_INIT_C;
  signal tin  : TrigRegType;
  
  type RegType is record
    afull    : sl;
    afullcnt : slv(31 downto 0);
    clear    : sl;
    start    : sl;
    l1in     : slv(1 downto 0);
    l1ina    : slv(1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    afull     => '0',
    afullcnt  => (others=>'0'),
    clear     => '1',
    start     => '0',
    l1in      => (others=>'0'),
    l1ina     => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal l0inacc, sl0inacc : sl;
  signal l1inacc, sl1inacc : sl;
  signal l1inrej, sl1inrej : sl;
  
begin

  afullOut  <= r.afull;
  afullCnt  <= r.afullcnt;
  ql1in     <= r.l1in (0);
  ql1ina    <= r.l1ina(0);
  clear     <= r.clear;
  start     <= r.start;

  --
  --  Must do the logical operations before crossing clock domains
  --
  t_comb : process ( triggerRst, t, triggerData ) is
    variable v : TrigRegType;
  begin
    v := t;
    v.l0inacc := triggerData.valid and triggerData.l0Accept;
    v.l1inacc := triggerData.valid and triggerData.l1Expect and     triggerData.l1Accept;
    v.l1inrej := triggerData.valid and triggerData.l1Expect and not triggerData.l1Accept;
    if triggerRst = '1' then
      v := TRIG_REG_INIT_C;
    end if;
    tin <= v;
  end process t_comb;

  t_seq : process ( triggerClk ) is
  begin
    if rising_edge(triggerClk) then
      t <= tin;
    end if;
  end process t_seq;

  U_L0INACC : entity surf.SynchronizerOneShot
    port map ( clk     => clk,
               dataIn  => t.l0inacc,
               dataOut => sl0inacc );

  U_L1INACC : entity surf.SynchronizerOneShot
    port map ( clk     => clk,
               dataIn  => t.l1inacc,
               dataOut => sl1inacc );

  U_L1INREJ : entity surf.SynchronizerOneShot
    port map ( clk      => clk,
               dataIn   => t.l1inrej,
               dataOut  => sl1inrej );

  process (r, rst, sl0inacc, sl1inacc, sl1inrej, afullIn, enable) is
    variable v   : RegType;
  begin  -- process
    v := r;

    v.afull := uOr(afullIn);
    if r.afull='1' then
      v.afullcnt := r.afullcnt+1;
    end if;

    v.l1in  := (sl1inacc or sl1inrej) & r.l1in (r.l1in'left  downto 1) ;
    v.l1ina := (sl1inacc            ) & r.l1ina(r.l1ina'left downto 1);

    v.clear := not uOr(enable);
    
    v.start := '0';
    if sl0inacc = '1' then
      v.start := '1';
    end if;
    
    if rst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;
