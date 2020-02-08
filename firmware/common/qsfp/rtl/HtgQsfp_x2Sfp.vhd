-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HtgQsfp_x2Sfp.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2019-02-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface to sensor link MGT
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 HSD Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
 
library work;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

entity QsfpCard is
  port ( axilClk         : in  sl;
         axilRst         : in  sl;
         regReadMaster   : in  AxiLiteReadMasterType;
         regReadSlave    : out AxiLiteReadSlaveType;
         regWriteMaster  : in  AxiLiteWriteMasterType;
         regWriteSlave   : out AxiLiteWriteSlaveType;
         qsfpReadMaster  : in  AxiLiteReadMasterArray (1 downto 0);
         qsfpReadSlave   : out AxiLiteReadSlaveArray  (1 downto 0);
         qsfpWriteMaster : in  AxiLiteWriteMasterArray(1 downto 0);
         qsfpWriteSlave  : out AxiLiteWriteSlaveArray (1 downto 0);
         --
         miob            : inout slv(11 downto 0);
         m2cPrsN         : in    sl;
         m2cPg           : in    sl;
         qpllLock        : in    sl;
         qpllReset       : in    sl );
end QsfpCard;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture HtgQsfp_x2Sfp of QsfpCard is

  type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
    pgpClkEn  : sl;
    usrClkEn  : sl;
    usrClkSel : sl;
    qsfpRstN  : sl;
    phyRst    : sl;
    pllTxRst  : slv(3 downto 0);
    pllRxRst  : slv(3 downto 0);
    pgpTxRst  : slv(3 downto 0);
    pgpRxRst  : slv(3 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    pgpClkEn  => '1',
    usrClkEn  => '0',
    usrClkSel => '0',
    qsfpRstN  => '1',
    phyRst    => '1',
    pllTxRst  => (others=>'0'),
    pllRxRst  => (others=>'0'),
    pgpTxRst  => (others=>'0'),
    pgpRxRst  => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal qsfpPrsN : slv(1 downto 0);
  signal qsfpIntN : slv(1 downto 0);

  constant QSFP_DEVICE_MAP_C : I2cAxiLiteDevArray(0 downto 0) := (
    0 => MakeI2cAxiLiteDevType("1010000", 8, 8, '0' ) );
  
begin  -- rtl

  qsfpPrsN <= "11";
  qsfpIntN <= "11";
  
  comb : process ( r, axilRst, m2cPg, m2cPrsN, regReadMaster, regWriteMaster ) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn(ep, regWriteMaster, regReadMaster, v.axilWriteSlave, v.axilReadSlave);
    ep.axiReadSlave.rdata := (others=>'0');

    axiSlaveRegisterR( ep, toSlv(0,5),  0, m2cPrsN );
    axiSlaveRegisterR( ep, toSlv(0,5),  1, m2cPg );
    axiSlaveRegister ( ep, toSlv(4,5),  0, v.pgpClkEn );
    axiSlaveRegister ( ep, toSlv(4,5),  1, v.usrClkEn );
    axiSlaveRegister ( ep, toSlv(4,5),  2, v.usrClkSel);
    axiSlaveRegister ( ep, toSlv(4,5),  3, v.qsfpRstN);
    axiSlaveRegister ( ep, toSlv(4,5),  4, v.phyRst);
    axiSlaveRegister ( ep, toSlv(4,5), 16, v.pllTxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 20, v.pllRxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 24, v.pgpTxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 28, v.pgpRxRst);

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    if axilRst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    regWriteSlave <= r.axilWriteSlave;
    regReadSlave  <= r.axilReadSlave;
    
    miob(5)     <= r.pgpClkEn ;
    miob(1)     <= r.usrClkEn ;
    miob(11)    <= r.usrClkSel;
    miob(0)     <= r.qsfpRstN;
  end process;

  seq: process ( axilClk ) is
  begin
    if rising_edge(axilClk) then
      r <= r_in;
    end if;
  end process;

  --U_I2C : entity surf.AxiI2cRegMaster
  --  generic map ( DEVICE_MAP_G   => QSFP_DEVICE_MAP_C,
  --                AXI_CLK_FREQ_G => 125.0E+6 )
  --  port map ( scl            => miob(10),
  --             sda            => miob( 7),
  --             axiReadMaster  => qsfpReadMaster (0),
  --             axiReadSlave   => qsfpReadSlave  (0),
  --             axiWriteMaster => qsfpWriteMaster(0),
  --             axiWriteSlave  => qsfpWriteSlave (0),
  --             axiClk         => axilClk,
  --             axiRst         => axilRst );

  qsfpReadSlave (0) <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
  qsfpWriteSlave(0) <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
  qsfpReadSlave (1) <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
  qsfpWriteSlave(1) <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
  
end HtgQsfp_x2Sfp;
