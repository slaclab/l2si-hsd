-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Htg_x2Qsfp.vhd
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

library unisim;            
use unisim.vcomponents.all;  

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
architecture Htg_x2Qsfp of QsfpCard is

  type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
    --pgpClkEn  : sl;
    --usrClkEn  : sl;
    --usrClkSel : sl;
    oe_osc    : sl;
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
    --pgpClkEn  => '1',
    --usrClkEn  => '0',
    --usrClkSel => '0',
    oe_osc    => '1',
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

  qsfpPrsN <= miob(7 downto 6);
  qsfpIntN <= miob(9 downto 8);
  
  comb : process ( r, axilRst, m2cPg, m2cPrsN, qsfpPrsN, qsfpIntN, qpllLock, qpllReset,
                   regReadMaster, regWriteMaster ) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn(ep, regWriteMaster, regReadMaster, v.axilWriteSlave, v.axilReadSlave);
    ep.axiReadSlave.rdata := (others=>'0');

    axiSlaveRegisterR( ep, toSlv(0,5),  0, m2cPrsN);
    axiSlaveRegisterR( ep, toSlv(0,5),  1, m2cPg);
    axiSlaveRegisterR( ep, toSlv(0,5),  2, qsfpPrsN      );
    axiSlaveRegisterR( ep, toSlv(0,5),  4, qsfpIntN      );
    axiSlaveRegisterR( ep, toSlv(0,5),  8, qpllLock      );
    axiSlaveRegisterR( ep, toSlv(0,5), 12, qpllReset     );
    --axiSlaveRegister ( ep, toSlv(4,5),  0, v.pgpClkEn );
    --axiSlaveRegister ( ep, toSlv(4,5),  1, v.usrClkEn );
    --axiSlaveRegister ( ep, toSlv(4,5),  2, v.usrClkSel);
    --axiSlaveRegister ( ep, toSlv(4,5),  3, v.qsfpRstN);
    axiSlaveRegister ( ep, toSlv(4,5),  0, v.oe_osc);
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

    miob(10)    <= r.oe_osc;
    --pgpClkEn    <= r.pgpClkEn ;
    --usrClkEn    <= r.usrClkEn ;
    --usrClkSel   <= r.usrClkSel;
    miob(4) <= r.qsfpRstN;
    miob(5) <= r.qsfpRstN;
  end process;

  seq: process ( axilClk ) is
  begin
    if rising_edge(axilClk) then
      r <= r_in;
    end if;
  end process;

  GEN_QSFP_I2C : for i in 0 to 1 generate
    U_I2C : entity surf.AxiI2cRegMaster
      generic map ( DEVICE_MAP_G   => QSFP_DEVICE_MAP_C,
                    AXI_CLK_FREQ_G => 125.0E+6 )
      port map ( scl            => miob(2*i+0),
                 sda            => miob(2*i+1),
                 axiReadMaster  => qsfpReadMaster (i),
                 axiReadSlave   => qsfpReadSlave  (i),
                 axiWriteMaster => qsfpWriteMaster(i),
                 axiWriteSlave  => qsfpWriteSlave (i),
                 axiClk         => axilClk,
                 axiRst         => axilRst );
  end generate;
    
end Htg_x2Qsfp;
