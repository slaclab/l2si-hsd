-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TriggerSolo.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-08-11
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
use surf.AxiStreamPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmExtensionPkg.all;

use work.FmcPkg.all;

entity TriggerSolo is
  generic ( EVENT_AXIS_CONFIG_G : AxiStreamConfigType := EVENT_AXIS_CONFIG_C );
  port ( clk             :  in sl;
         rst             :  in sl;
         enable          :  in sl;
         swtrig          :  in sl;
         triggerIn       :  in sl; -- asynchronous
         triggerData     : out TriggerEventDataType;
         eventAxisMaster : out AxiStreamMasterType;
         eventAxisSlave  :  in AxiStreamSlaveType );
end TriggerSolo;

architecture mapping of TriggerSolo is

  constant FIFO_ADDR_WIDTH_C : integer := 5;

  type RegType is record
    fifoRst     : sl;
    count       : slv(31 downto 0);
    triggerData : TriggerEventDataType;
    axisMaster  : AxiStreamMasterType;
  end record;

  constant REG_INIT_C : RegType := (
    fifoRst     => '1',
    count       => (others=>'0'),
    triggerData => XPM_EVENT_DATA_INIT_C,
    axisMaster  => axiStreamMasterInit(EVENT_AXIS_CONFIG_C));

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal triggerLevel : sl;
  signal trigger : sl;
  signal axisSlave : AxiStreamSlaveType;
  
begin

  triggerLevel <= triggerIn or swtrig;
  
  U_Trigger : entity surf.SynchronizerOneShot
    port map ( clk     => clk,
               dataIn  => triggerLevel,
               dataOut => trigger );

  -----------------------------------------------
  -- Buffer event data in a fifo
  -----------------------------------------------
   U_AxiStreamFifoV2_1 : entity surf.AxiStreamFifoV2
      generic map (
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => false,
         FIFO_PAUSE_THRESH_G => 16,
         SLAVE_AXI_CONFIG_G  => EVENT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_G)
      port map (
         sAxisClk        => clk,                -- [in]
         sAxisRst        => r.fifoRst,          -- [in]
         sAxisMaster     => r.axisMaster,       -- [in]
         sAxisSlave      => axisSlave,          -- [out]
         mAxisClk        => clk,                -- [in]
         mAxisRst        => rst,                -- [in]
         mAxisMaster     => eventAxisMaster,    -- [out]
         mAxisSlave      => eventAxisSlave);    -- [in]


  comb : process ( r, rst, trigger, swtrig, axisSlave, enable ) is
    variable v : RegType;
    variable eventHeader : EventHeaderType;
  begin
    v := r;

    v.fifoRst           := '0';
    v.triggerData.valid := '0';
    v.axisMaster.tLast  := '1';
    
    if axisSlave.tReady = '1' then
      v.axisMaster.tValid := '0';
    end if;
    
    if trigger = '1' and v.axisMaster.tValid = '0' then
      v.triggerData.valid    := '1';
      v.triggerData.l0Accept := '1';
      v.triggerData.l0Tag    := resize(r.count,5);
      v.triggerData.l0Reject := '0';
      v.triggerData.l1Expect := '1';
      v.triggerData.l1Accept := '1';
      v.triggerData.l1Tag    := resize(r.count,5);

      eventHeader.pulseId     := resize(r.count,64);
      eventHeader.timeStamp   := resize(r.count,64);
      eventHeader.count       := resize(r.count,eventHeader.count'length);
      eventHeader.triggerInfo := resize(toSlv(v.triggerData),16);
      eventHeader.partitions  := toSlv(1,eventHeader.partitions'length);

      v.axisMaster.tValid     := '1';
      v.axisMaster.tData(EVENT_HEADER_BITS_C-1 downto 0) := toSlv(eventHeader);
      v.axisMaster.tDest(0)   := '0';
      v.count := r.count+1;
    end if;

    if rst = '1' or enable = '0' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process seq;
  
end mapping;
