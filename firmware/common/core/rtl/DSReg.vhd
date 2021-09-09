-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DSReg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2021-06-29
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

entity DSReg is
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
--    dmaFullThr          : out slv(23 downto 0);
--    dmaHistEna          : out sl;
    adcSyncRst          : out sl;
    dmaRst              : out sl;
    fmcRst              : out slv(1 downto 0);
    fbRst               : out sl;
    fbPLLRst            : out sl;
    -- Status
    irqReq              : in  sl;
    rstCount            : out sl;
    dmaClk              : in  sl := '0';
    status              : in  QuadAdcStatusType );
end DSReg;

architecture mapping of DSReg is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    irqEnable      : sl;
    countReset     : sl;
--    dmaFullThr     : slv(23 downto 0);
--    dmaHistEna     : sl;
    config         : QuadAdcConfigType;
    adcSyncRst     : sl;
    dmaRst         : sl;
    fmcRst         : slv(1 downto 0);
    fbRst          : sl;
    fbPLLRst       : sl;
    cacheSel       : slv(5 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    irqEnable      => '0',
    countReset     => '0',
--    dmaFullThr     => (others=>'1'),
--    dmaHistEna     => '0',
    config         => QUAD_ADC_CONFIG_INIT_C,
    adcSyncRst     => '1',
    dmaRst         => '0',
    fmcRst         => "00",
    fbRst          => '0',
    fbPLLRst       => '0',
    cacheSel       => (others=>'0') );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal cacheSel : slv(5 downto 0);
  signal icache   : integer range 0 to 15;
  signal istream  : integer range 0 to 3;

  signal cacheS       : CacheType;
  signal cacheV, cacheSV : slv(CACHETYPE_LEN_C-1 downto 0);

  signal statusS : QuadAdcStatusType;
  signal statusV, statusVS : slv(QADC_STATUS_TYPE_LEN_C-1 downto 0);
  
begin  -- mapping

  config         <= r.config;
--  dmaFullThr     <= r.dmaFullThr;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  irqEnable      <= r.irqEnable;
  rstCount       <= r.countReset;
--  dmaHistEna     <= r.dmaHistEna;
  adcSyncRst     <= r.adcSyncRst;
  dmaRst         <= r.dmaRst;
  fmcRst         <= r.fmcRst;
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
    variable axilStatus : AxiLiteStatusType;
    variable cacheS_state : slv(3 downto 0);
    variable cacheS_trigd : slv(3 downto 0);
    procedure axilSlaveRegisterR (addr : in slv; reg : in slv) is
    begin
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, 0, reg);
    end procedure;
    procedure axilSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
    begin
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
    begin
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterR (addr : in slv; reg : in slv; ack : out sl) is
    begin
      if (axilStatus.readEnable = '1') then
         if (std_match(axilReadMaster.araddr(addr'length-1 downto 0), addr)) then
            v.axilReadSlave.rdata(reg'range) := reg;
            axiSlaveReadResponse(v.axilReadSlave);
            ack := '1';
         end if;
      end if;
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveDefault (
      axilResp : in slv(1 downto 0)) is
    begin
      axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, axilResp);
    end procedure;
  begin  -- process
    v  := r;
    v.adcSyncRst := '0';
    
    sReg(0) := irqReq;
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);
    
    axilSlaveRegisterW(toSlv( 0,12), 0, v.irqEnable);
    axilSlaveRegisterR(toSlv( 4,12), sReg);
--    axilSlaveRegisterR(toSlv( 8,12), status.partitionAddr);
--    axilSlaveRegisterW(toSlv(12,12),  0, v.dmaFullThr);
    axilSlaveRegisterW(toSlv(16,12),  0, v.countReset);
--    axilSlaveRegisterW(toSlv(16,12),  1, v.dmaHistEna);
    axilSlaveRegisterW(toSlv(16,12),  2, v.config.dmaTest);
    axilSlaveRegisterW(toSlv(16,12),  3, v.adcSyncRst);
    axilSlaveRegisterW(toSlv(16,12),  4, v.dmaRst);
    axilSlaveRegisterW(toSlv(16,12),  5, v.fbRst);
    axilSlaveRegisterW(toSlv(16,12),  6, v.fbPLLRst);
    axilSlaveRegisterW(toSlv(16,12),  8, v.config.trigShift);
    axilSlaveRegisterW(toSlv(16,12), 28, v.fmcRst);
    axilSlaveRegisterW(toSlv(16,12), 30, v.config.acqEnable);
    axilSlaveRegisterW(toSlv(20,12),  0, v.config.rateSel);
    axilSlaveRegisterW(toSlv(20,12), 13, v.config.destSel);
    axilSlaveRegisterW(toSlv(24,12),  0, v.config.enable);
    axilSlaveRegisterW(toSlv(24,12),  8, v.config.intlv);
    axilSlaveRegisterW(toSlv(24,12), 16, v.config.partition(0));
    axilSlaveRegisterW(toSlv(24,12), 20, v.config.partition(1));
    axilSlaveRegisterW(toSlv(24,12), 24, v.config.inhibit);
    axilSlaveRegisterW(toSlv(28,12),  0, v.config.samples);
    axilSlaveRegisterW(toSlv(32,12),  0, v.config.prescale);
    axilSlaveRegisterW(toSlv(36,12),  0, v.config.offset);
    
    axilSlaveRegisterR(toSlv(40,12), status.eventCount(0));
    axilSlaveRegisterR(toSlv(44,12), status.eventCount(1));
    axilSlaveRegisterR(toSlv(48,12), status.dmaCtrlCount);
    axilSlaveRegisterR(toSlv(52,12), status.eventCount(2));
    axilSlaveRegisterR(toSlv(56,12), status.eventCount(3));
    axilSlaveRegisterR(toSlv(60,12), status.eventCount(4));

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

    axilSlaveRegisterW(toSlv(64,12),  0, v.cacheSel );
    axilSlaveRegisterR(toSlv(68,12),  0, cacheS_state );
    axilSlaveRegisterR(toSlv(68,12),  4, cacheS_trigd );
    axilSlaveRegisterR(toSlv(68,12),  8, cacheS.skip );
    axilSlaveRegisterR(toSlv(68,12),  9, cacheS.ovflow );
    axilSlaveRegisterR(toSlv(72,12),  0, resize(cacheS.baddr,16) );
    axilSlaveRegisterR(toSlv(72,12), 16, resize(cacheS.eaddr,16) );

    --axilSlaveRegisterR(toSlv(76,12),  0, statusS.msgDelaySet );
    --axilSlaveRegisterR(toSlv(76,12), 16, statusS.msgDelayGet );

    --axilSlaveRegisterR(toSlv(80,12),  0, statusS.headerCntL0 );
    --axilSlaveRegisterR(toSlv(80,12), 24, statusS.headerCntOF );

    axilSlaveRegisterW(toSlv(104,12), 0, v.config.localId );
    --axilSlaveRegisterR(toSlv(108,12), 0, statusS.upstreamId(0) );
    --for i in 0 to 3 loop
    --  axilSlaveRegisterR(toSlv(112+4*i,12), 0, statusS.dnstreamId(i) );
    --end loop;
    
    axilSlaveDefault(AXI_RESP_OK_C); 
    
    rin <= v;
  end process;

  U_ICache : entity surf.SynchronizerVector
    generic map ( WIDTH_G => 6 )
    port map ( clk     => dmaClk,
               dataIn  => r.cacheSel,
               dataOut => cacheSel);
  istream <= conv_integer(cacheSel(5 downto 4));
  icache  <= conv_integer(cacheSel(3 downto 0));
  cacheV  <= cacheToSlv(status.eventCache(istream)(icache));
  U_CacheS : entity surf.SynchronizerVector
    generic map ( WIDTH_G => cacheV'length )
    port map ( clk     => axiClk,
               dataIn  => cacheV,
               dataOut => cacheSV );
  cacheS <= toCacheType(cacheSV);
  
end mapping;
