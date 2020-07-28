-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DSReg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-07-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use work.QuadAdcPkg.all;

entity ChipAdcReg is
  generic (
    TPD_G      : time    := 1 ns );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- Configuration
    irqEnable           : out sl;
    config              : out QuadAdcConfigType;
    adcSyncRst          : out sl;
    dmaRst              : out sl;
    fbRst               : out sl;
    fbPLLRst            : out sl;
    -- Status
    irqReq              : in  sl;
    rstCount            : out sl;
    dmaClk              : in  sl := '0';
    status              : in  QuadAdcStatusType );
end ChipAdcReg;

architecture mapping of ChipAdcReg is

  constant AW : integer := 12;   -- axi lite address width
  
  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    irqEnable      : sl;
    countReset     : sl;
    config         : QuadAdcConfigType;
    adcSyncRst     : sl;
    dmaRst         : sl;
    fbRst          : sl;
    fbPLLRst       : sl;
    streamSel      : slv(1 downto 0);
    cacheSel       : slv(3 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    irqEnable      => '0',
    countReset     => '0',
    config         => QUAD_ADC_CONFIG_INIT_C,
    adcSyncRst     => '1',
    dmaRst         => '0',
    fbRst          => '0',
    fbPLLRst       => '0',
    streamSel      => (others=>'0'),
    cacheSel       => (others=>'0') );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal streamSel : slv(1 downto 0);
  signal istream   : integer range 0 to MAX_STREAMS_C-1;
  signal cacheSel : slv(3 downto 0);
  signal icache   : integer range 0 to 15;

  signal cacheS       : CacheType;
  signal cacheV, cacheSV : slv(CACHETYPE_LEN_C-1 downto 0);

  signal statusS : QuadAdcStatusType;
  signal statusV, statusVS : slv(QADC_STATUS_TYPE_LEN_C-1 downto 0);

begin  -- mapping

  config         <= r.config;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  irqEnable      <= r.irqEnable;
  rstCount       <= r.countReset;
  adcSyncRst     <= r.adcSyncRst;
  dmaRst         <= r.dmaRst;
  fbRst          <= r.fbRst;
  fbPLLRst       <= r.fbPLLRst;

  statusV        <= toSlv(status);
  statusS        <= toQadcStatus(statusVS);
  
  U_StatusVS : entity surf.SynchronizerVector
    generic map (WIDTH_G => QADC_STATUS_TYPE_LEN_C)
    port map ( clk     => axiClk,
               dataIn  => statusV,
               dataOut => statusVS );
  
  process (axiClk)
  begin  -- process
    if rising_edge(axiClk) then
      r <= rin;
    end if;
  end process;

  process (r,axilReadMaster,axilWriteMaster,axiRst,status,irqReq,cacheS,statusS) is
    variable v : RegType;
    variable sReg : slv(0 downto 0);
    variable cacheS_state : slv(3 downto 0);
    variable cacheS_trigd : slv(3 downto 0);
    variable axilEp : AxiLiteEndpointType;
  begin  -- process
    v  := r;
    v.adcSyncRst := '0';
    
    sReg(0) := irqReq;
    axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    v.axilReadSlave.rdata := (others=>'0');
    
    axiSlaveRegister (axilEp, toSlv( 0,AW), 0, v.irqEnable);
    axiSlaveRegisterR(axilEp, toSlv( 4,AW), 0, sReg);

    axiSlaveRegister (axilEp, toSlv(16,AW),  0, v.countReset);
    axiSlaveRegister (axilEp, toSlv(16,AW),  2, v.config.dmaTest);
    axiSlaveRegister (axilEp, toSlv(16,AW),  3, v.adcSyncRst);
    axiSlaveRegister (axilEp, toSlv(16,AW),  4, v.dmaRst);
    axiSlaveRegister (axilEp, toSlv(16,AW),  5, v.fbRst);
    axiSlaveRegister (axilEp, toSlv(16,AW),  6, v.fbPLLRst);
    axiSlaveRegister (axilEp, toSlv(16,AW),  8, v.config.trigShift);
    axiSlaveRegister (axilEp, toSlv(16,AW), 31, v.config.acqEnable);
    axiSlaveRegister (axilEp, toSlv(20,AW),  0, v.config.rateSel);
    axiSlaveRegister (axilEp, toSlv(20,AW), 13, v.config.destSel);
    axiSlaveRegister (axilEp, toSlv(24,AW),  0, v.config.enable);
    axiSlaveRegister (axilEp, toSlv(24,AW),  8, v.config.intlv);
    axiSlaveRegister (axilEp, toSlv(24,AW), 16, v.config.partition);
    axiSlaveRegister (axilEp, toSlv(24,AW), 20, v.config.inhibit);
    axiSlaveRegister (axilEp, toSlv(28,AW),  0, v.config.samples);
    axiSlaveRegister (axilEp, toSlv(32,AW),  0, v.config.prescale);
    axiSlaveRegister (axilEp, toSlv(36,AW),  0, v.config.offset);
    
    axiSlaveRegisterR(axilEp, toSlv(40,AW), 0, status.eventCount(0));
    axiSlaveRegisterR(axilEp, toSlv(44,AW), 0, status.eventCount(1));
    axiSlaveRegisterR(axilEp, toSlv(48,AW), 0, status.dmaCtrlCount);
    axiSlaveRegisterR(axilEp, toSlv(52,AW), 0, status.eventCount(2));
    axiSlaveRegisterR(axilEp, toSlv(56,AW), 0, status.eventCount(3));
    axiSlaveRegisterR(axilEp, toSlv(60,AW), 0, status.eventCount(4));

    case cacheS.state is
      when EMPTY_S   => cacheS_state := x"0";
      when OPEN_S    => cacheS_state := x"1";
      when CLOSED_S  => cacheS_state := x"2";
      when READING_S => cacheS_state := x"3";
      when others    => cacheS_state := x"4";
    end case;
    case cacheS.trigd is
      when WAIT_T    => cacheS_trigd := x"0";
      when ACCEPT_T  => cacheS_trigd := x"1";
      when others    => cacheS_trigd := x"2";
    end case;

    axiSlaveRegister (axilEp, toSlv(64,AW),  0, v.cacheSel  );
    axiSlaveRegister (axilEp, toSlv(64,AW),  4, v.streamSel );
    axiSlaveRegisterR(axilEp, toSlv(68,AW),  0, cacheS_state );
    axiSlaveRegisterR(axilEp, toSlv(68,AW),  4, cacheS_trigd );
    axiSlaveRegisterR(axilEp, toSlv(68,AW),  8, cacheS.skip );
    axiSlaveRegisterR(axilEp, toSlv(68,AW),  9, cacheS.ovflow );
    axiSlaveRegisterR(axilEp, toSlv(68,AW), 16, cacheS.tag );
    axiSlaveRegisterR(axilEp, toSlv(72,AW),  0, resize(cacheS.baddr,16) );
    axiSlaveRegisterR(axilEp, toSlv(72,AW), 16, resize(cacheS.eaddr,16) );

    axiSlaveRegisterR(axilEp, toSlv(76,AW),  0, statusS.build.state );
    axiSlaveRegisterR(axilEp, toSlv(76,AW),  4, statusS.build.dumps );
    axiSlaveRegisterR(axilEp, toSlv(76,AW),  8, statusS.build.hdrv  );
    axiSlaveRegisterR(axilEp, toSlv(76,AW),  9, statusS.build.valid );
    axiSlaveRegisterR(axilEp, toSlv(76,AW), 10, statusS.build.ready );
    
    axiSlaveRegister (axilEp, toSlv(104,AW), 0, v.config.localId );
    
    axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C); 
    
    rin <= v;
  end process;

  istream <= conv_integer(r.streamSel);
  icache  <= conv_integer(r.cacheSel);

  cacheS <= status.eventCache(istream)(icache);

end mapping;
