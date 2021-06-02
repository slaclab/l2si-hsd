-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelData.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2021-06-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Merges event header and channel data stream.
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
use surf.SsiPkg.all;

use work.QuadAdcPkg.all;

entity QuadAdcChannelData is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    SAXIS_CONFIG_G    : AxiStreamConfigType;
    MAXIS_CONFIG_G    : AxiStreamConfigType;
    DEBUG_G           : boolean := false );
  port (
    dmaClk       :  in sl;
    dmaRst       :  in sl;
    --
    eventHdr     :  in slv(255 downto 0);
    eventHdrV    :  in sl;
    noPayload    :  in sl;
    eventHdrRd   : out sl;
    --
    chnMaster    :  in AxiStreamMasterType;
    chnSlave     : out AxiStreamSlaveType;
    dmaMaster    : out AxiStreamMasterType;
    dmaSlave     :  in AxiStreamSlaveType;
    --
    status       : out BuildStatusType );
end QuadAdcChannelData;

architecture mapping of QuadAdcChannelData is

  type RdStateType is (S_WAIT, S_IDLE, S_READHDR, S_WRITEHDR,
                       S_READCHAN, S_DUMP);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    hdrRd    : sl;
    state    : RdStateType;
    master   : AxiStreamMasterType;
    slave    : AxiStreamSlaveType;
    tmo      : integer range 0 to TMO_VAL_C;
    dumps    : slv(3 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    hdrRd     => '0',
    state     => S_IDLE,
    master    => AXI_STREAM_MASTER_INIT_C,
    slave     => AXI_STREAM_SLAVE_INIT_C,
    tmo       => TMO_VAL_C,
    dumps     => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal tSlave : AxiStreamSlaveType;

  constant DEBUG_C : boolean := DEBUG_G;

  component ila_0
    port ( clk   : in sl;
           probe0 : in slv(255 downto 0) );
  end  component;

  signal r_state : slv(2 downto 0);
  signal hdrtag  : slv(4 downto 0);
  signal chntag  : slv(4 downto 0);

begin  -- mapping

  assert (SAXIS_CONFIG_G.TDATA_BYTES_C = 32)
    report "EventHeader insertion requires TDATA_BYTES_C=16 or 32"
    severity error;

  status.state <= r_state;
  status.dumps <= r.dumps;
  status.hdrv  <= eventHdrV;
  status.valid <= r.master.tValid;
  status.ready <= dmaSlave.tReady;
  
  r_state <= "000" when r.state = S_WAIT else
             "001" when r.state = S_IDLE else
             "010" when r.state = S_READHDR else
             "011" when r.state = S_WRITEHDR else
             "100" when r.state = S_READCHAN else
             "101";

  hdrtag  <= eventHdr(85 downto 81);
  chntag  <= chnMaster.tData(84 downto 80);
  
  GEN_DEBUG : if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk    => dmaClk,
                 probe0(0) => dmaRst,
                 probe0(1) => eventHdrV,
                 probe0(2) => noPayload,
                 probe0(3) => chnMaster.tValid,
                 probe0(4) => chnMaster.tLast,
                 probe0(5) => dmaSlave.tReady,
                 probe0(21 downto 6)  => eventHdr(95 downto 80),
                 probe0(26 downto 22) => hdrtag,
                 probe0(31 downto 27) => chntag,
                 probe0(37 downto 32) => (others=>'0'),
                 probe0(69 downto 38) => chnMaster.tData(31 downto 0),
                 probe0(72 downto 70) => r_state,
                 probe0(73)           => tSlave.tReady,
                 probe0(74)           => r.hdrRd,
                 probe0(79 downto 75) => eventHdr(68 downto 64), -- LCLS1 PID
                 probe0(255 downto 80) => (others=>'0') );
  end generate;
  
  U_FIFO : entity surf.AxiStreamFifoV2
    generic map ( FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
                  SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_G,
                  MASTER_AXI_CONFIG_G => MAXIS_CONFIG_G )
    port map ( sAxisClk    => dmaClk,
               sAxisRst    => dmaRst,
               sAxisMaster => r.master,
               sAxisSlave  => tSlave,
               mAxisClk    => dmaClk,
               mAxisRst    => dmaRst,
               mAxisMaster => dmaMaster,
               mAxisSlave  => dmaSlave );

  
  process (r, dmaRst, eventHdr, eventHdrV, noPayload,
           tSlave, chnMaster) is
    variable v   : RegType;
  begin  -- process
    v := r;
    v.hdrRd        := '0';
    v.slave.tReady := '0';

    if tSlave.tReady='1' then
      v.master.tValid := '0';
      ssiSetUserSof(SAXIS_CONFIG_G, v.master, '0');
    end if;

    --  This isn't a good idea
    --
    -- if r.state = S_READCHAN and r.master.tValid='0' then
    --   v.tmo := r.tmo-1;
    -- else
    --   v.tmo := TMO_VAL_C;
    -- end if;
    
    case r.state is
      when S_WAIT =>
        v.state := S_IDLE;
      when S_IDLE =>
        if eventHdrV='1' then
          v.state := S_READHDR;
          v.tmo   := TMO_VAL_C;
        end if;
      when S_READHDR =>
        if v.master.tValid='0' then
          ssiSetUserSof(SAXIS_CONFIG_G, v.master, '1');
          v.master.tData(255 downto 0) := eventHdr(255 downto 0);
          v.master.tKeep               := genTKeep(32);
          if noPayload = '1' then
            v.master.tValid := '1';
            v.master.tLast  := '1';
            ssiSetUserEofe(SAXIS_CONFIG_G,v.master,'0');
            v.hdrRd := '1';
            v.state := S_WAIT;
          else
            v.master.tValid := '0';
            v.master.tLast  := '0';
            v.state := S_WRITEHDR;
          end if;
        end if;
      when S_WRITEHDR =>
        if v.master.tValid='0' and chnMaster.tValid='1' then
          v.master.tValid := '1';
          v.master.tLast  := chnMaster.tLast;
          v.slave.tReady  := '1';
          v.hdrRd         := '1';
          v.master.tData(223 downto 212) := chnMaster.tData(223 downto 212);
          v.state         := S_READCHAN;
          if chnMaster.tLast = '1' then  -- payload prescaled away
            v.state       := S_WAIT;
          end if;
        end if;
      when S_READCHAN =>
        if v.master.tValid='0' then
          v.master       := chnMaster;
          v.slave.tReady := chnMaster.tValid;
          if chnMaster.tLast='1' then
            ssiSetUserEofe(SAXIS_CONFIG_G,v.master,'0');
            v.state := S_WAIT; 
          end if;
        end if;
      when S_DUMP =>
        v.slave.tReady := '1';
        if chnMaster.tLast='1' then
          v.state := S_WAIT;
        end if;
      when others => NULL;
    end case;

    if r.tmo = 0 then
      v.dumps := r.dumps+1;
      v.state := S_DUMP;
      ssiSetUserEofe(SAXIS_CONFIG_G,v.master,'1');
      v.master.tValid := '1';
      v.master.tLast  := '1';
    end if;
    
    chnSlave   <= v.slave;
    eventHdrRd <= r.hdrRd;

    if dmaRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;

  end process;

  process (dmaClk)
  begin  -- process
    if rising_edge(dmaClk) then
      r <= rin;
    end if;
  end process;
  
end mapping;
