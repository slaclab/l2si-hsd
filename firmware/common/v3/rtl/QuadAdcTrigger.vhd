-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcTrigger.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-08-09
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
use work.QuadAdcPkg.all;
use work.FmcPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity QuadAdcTrigger is
  generic ( NCHAN_C : integer := 1 );
  port ( triggerClk  : in  sl;
         triggerRst  : in  sl;
         triggerData : in  TriggerEventDataType;
         --
         clk       : in  sl;
         rst       : in  sl;
         trigIn    : in  slv(ROW_SIZE-1 downto 0);
         afullIn   : in  slv(NCHAN_C-1 downto 0);
         enable    : in  slv(NCHAN_C-1 downto 0);
         --
         afullOut  : out sl;
         afullCnt  : out slv(31 downto 0);
         ql1in     : out sl;
         ql1ina    : out sl;
         shift     : out slv(31 downto 0);
         clear     : out sl;
         start     : out sl;
         l0tag     : out slv(4 downto 0);
         l1tag     : out slv(4 downto 0) );
end QuadAdcTrigger;

architecture mapping of QuadAdcTrigger is
  type SyncStateType is (S_SHIFT_S, S_WAIT_S);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    afull    : sl;
    afullcnt : slv(31 downto 0);
    clear    : sl;
    start    : sl;
    syncState: SyncStateType;
    adcShift : slv(ROW_IDXB-1 downto 0);
    trigd1   : slv(ROW_SIZE-1 downto 0);
    trigd2   : slv(ROW_SIZE-1 downto 0);
    trig     : slv(ROW_SIZE-1 downto 0);
    l1in     : slv(4 downto 0);
    l1ina    : slv(4 downto 0);
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    afull     => '0',
    afullcnt  => (others=>'0'),
    clear     => '1',
    start     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>'0'),
    l1in      => (others=>'0'),
    l1ina     => (others=>'0'),
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal triggerDataSlv       : slv(47 downto 0);
  signal triggerDataSlvSync   : slv(47 downto 0);
  signal triggerDataValidSync : sl;
  signal triggerDataSync      : TriggerEventDataType;

begin

  afullOut  <= r.afull;
  afullCnt  <= r.afullcnt;
  ql1in     <= r.l1in (0);
  ql1ina    <= r.l1ina(0);
  shift     <= resize(r.trigd2 & r.trigd1 & r.adcShift,32);
  clear     <= r.clear;
  start     <= r.start;
  l0tag     <= triggerDataSync.l0Tag;
  l1tag     <= triggerDataSync.l1Tag;
  
  triggerDataSlv  <= toSlv(triggerData);
  triggerDataSync <= toXpmEventDataType(triggerDataSlvSync);
  
  U_L0L1 : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => triggerDataSlv'length )
    port map ( wr_clk   => triggerClk,
               din      => triggerDataSlv,
               rd_clk   => clk,
               valid    => triggerDataValidSync,
               dout     => triggerDataSlvSync );

  process (r, rst, trigIn, afullIn, enable,
           triggerDataSync, triggerDataValidSync) is
    variable v   : RegType;
    variable tshift : integer;
    variable l0ina : sl;
    variable l1in  : sl;
    variable l1ina : sl;
  begin  -- process
    v := r;

    v.trigd1 := trigIn;
    v.trigd2 := r.trigd1;
    v.trig   := r.trigd2;

    v.afull := uOr(afullIn);
    if r.afull='1' then
      v.afullcnt := r.afullcnt+1;
    end if;

    if triggerDataValidSync='1' and triggerDataSync.valid='1' then
      l0ina := triggerDataSync.l0Accept;
      l1in  := triggerDataSync.l1Expect;
      l1ina := triggerDataSync.l1Expect and
               triggerDataSync.l1Accept;
    else
      l0ina := '0';
      l1in  := '0';
      l1ina := '0';
    end if;
      
    v.l1in  := l1in  & r.l1in (r.l1in'left  downto 1) ;
    v.l1ina := l1ina & r.l1ina(r.l1ina'left downto 1);

    v.clear := not uOr(enable);
    
    v.start := '0';
    case (r.syncState) is
      when S_SHIFT_S =>
        if r.trigd1/=0 then
          v.start := uOr(enable);
          if r.trigd1(ROW_SIZE/2-1 downto 0)/=0 then
            v.adcShift := toSlv(         0,ROW_IDXB);
          else
            v.adcShift := toSlv(ROW_SIZE/2,ROW_IDXB);
          end if;
         
          v.syncState := S_WAIT_S;
        end if;
      when S_WAIT_S =>
        if r.trigd1=0 then
          v.syncState := S_SHIFT_S;
        end if;
      when others => NULL;
    end case;

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
