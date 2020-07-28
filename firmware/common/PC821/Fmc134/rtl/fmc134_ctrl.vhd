-------------------------------------------------------------------------------------
-- FILE NAME : fmc134_ctrl.vhd
--
-- AUTHOR    :
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       -
--             architecture -
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
--
-- Notes:
-------------------------------------------------------------------------------------
--  Disclaimer: LIMITED WARRANTY AND DISCLAIMER. These designs are
--              provided to you as is.  4DSP specifically disclaims any
--              implied warranties of merchantability, non-infringement, or
--              fitness for a particular purpose. 4DSP does not warrant that
--              the functions contained in these designs will meet your
--              requirements, or that the operation of these designs will be
--              uninterrupted or error free, or that defects in the Designs
--              will be corrected. Furthermore, 4DSP does not warrant or
--              make any representations regarding use or the results of the
--              use of the designs in terms of correctness, accuracy,
--              reliability, or otherwise.
--
--              LIMITATION OF LIABILITY. In no event will 4DSP or its
--              licensors be liable for any loss of data, lost profits, cost
--              or procurement of substitute goods or services, or for any
--              special, incidental, consequential, or indirect damages
--              arising from the use or operation of the designs or
--              accompanying documentation, however caused and on any theory
--              of liability. This limitation will apply even if 4DSP
--              has been advised of the possibility of such damage. This
--              limitation shall apply not-withstanding the failure of the
--              essential purpose of any limited remedies herein.
--
-------------------------------------------------------------------------------------

-- Library declarations
library ieee;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_1164.all;

library unisim;
  use unisim.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity fmc134_ctrl is
port (
  -- AXI Command Interface
  axilClk         : in  sl;
  axilRst         : in  sl;
  axilReadMaster  : in  AxiLiteReadMasterType;
  axilReadSlave   : out AxiLiteReadSlaveType;
  axilWriteMaster : in  AxiLiteWriteMasterType;
  axilWriteSlave  : out AxiLiteWriteSlaveType;

  -- Transceiver RX Interface
  rst_rxclk       : in  sl;
  rx_clk          : in  sl;
  clk320          : in  sl;
  status          : in  slv(31 downto 0);
  xcvr_rxrst      : out sl;
  sysref_sync_en  : out sl;

  rxdfeagchold    : out sl;
  rxdfelfhold     : out sl;
  rxdfetaphold    : out sl;
  rxdfetapovrden  : out sl;
  rxlpmgchold     : out sl;
  rxlpmhfhold     : out sl;
  rxlpmlfhold     : out sl;
  rxlpmoshold     : out sl;
  rxoshold        : out sl;
  rxcdrhold       : out sl;

  align_enable    : out sl;

  -- JESD204B RX Core Status
  adc_valid       : in  slv(3 downto 0);
  scrambling_en   : out sl;
  f_align_char    : out slv(7 downto 0);
  k_lmfc_cnt      : out slv(4 downto 0);

  -- Trigger Signals
  sw_trigger      : out sl;
  sw_trigger_en   : out sl;
  hw_trigger_en   : out sl;
  fpga_sync_out   : out sl;

  -- External Signals
  pg_m2c          : in  sl;
  prsnt_m2c_l     : in  sl;
  adc_ora         : in  Slv2Array(1 downto 0);
  adc_orb         : in  Slv2Array(1 downto 0);
  adc_ncoa        : out Slv2Array(1 downto 0);
  adc_ncob        : out Slv2Array(1 downto 0);
  adc_calstat     : in  slv      (1 downto 0);
  firefly_int     : in  sl;

  test_clocks     : in  slv      (15 downto 0)
);
end fmc134_ctrl;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture fmc_ctrl_syn of fmc134_ctrl is

-------------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------------
constant ADDR_FMC_INFO      : slv(7 downto 0) := x"00";
constant ADDR_TRANSCEIVER   : slv(7 downto 0) := x"04";
constant ADDR_STATUS        : slv(7 downto 0) := x"08";
constant ADDR_ADC_VAL       : slv(7 downto 0) := x"0c";
constant ADDR_SCRAMBLE      : slv(7 downto 0) := x"10";
constant ADDR_SW_TRIGGER    : slv(7 downto 0) := x"14";
constant ADDR_LMFC_CNT      : slv(7 downto 0) := x"18";
constant ADDR_F_ALIGN_CHAR  : slv(7 downto 0) := x"1c";
constant ADDR_ADC_PINS      : slv(7 downto 0) := x"20";
constant ADDR_ADC_PINS_R    : slv(7 downto 0) := x"24";
constant ADDR_TEST_CLKSEL   : slv(7 downto 0) := x"28";
constant ADDR_TEST_CLKFRQ   : slv(7 downto 0) := x"2c";

--constant KCHAR_F            : slv(7 downto 0) := x"3C"; -- K28.1
constant KCHAR_F            : slv(7 downto 0) := x"FC"; -- K28.7

--

type RegType is record
  sw_trigger     : sl;
  sw_trigger_en  : sl;
  hw_trigger_en  : sl;
  scrambling_en  : sl;
  f_align_char   : slv(7 downto 0);
  k_lmfc_cnt     : slv(4 downto 0);
  xcvr_rxrst     : sl;
  sysref_sync_en : sl;
  align_enable   : sl;
  status         : slv(31 downto 0);
  adc_valid      : slv(3 downto 0);
  adc_ora        : Slv2Array(1 downto 0);
  adc_orb        : Slv2Array(1 downto 0);
  adc_ncoa       : Slv2Array(1 downto 0);
  adc_ncob       : Slv2Array(1 downto 0);
  adc_calstat    : slv      (1 downto 0);
  rxdfeagchold   : sl;
  rxdfelfhold    : sl;
  rxdfetaphold   : sl;
  rxdfetapovrden : sl;
  rxlpmgchold    : sl;
  rxlpmhfhold    : sl;
  rxlpmlfhold    : sl;
  rxlpmoshold    : sl;
  rxoshold       : sl;
  rxcdrhold      : sl;
  fpga_sync      : sl;
  test_clksel    : slv( 3 downto 0);
  axilWriteSlave : AxiLiteWriteSlaveType;
  axilReadSlave  : AxiLiteReadSlaveType;
end record;
constant REG_INIT_C : RegType := (
  sw_trigger     => '0',
  sw_trigger_en  => '0',
  hw_trigger_en  => '0',
  scrambling_en  => '0',
  f_align_char   => KCHAR_F,
  k_lmfc_cnt     => "01111",
  xcvr_rxrst     => '0',
  sysref_sync_en => '0',
  align_enable   => '0',
  status         => (others=>'0'),
  adc_valid      => (others=>'0'),
  adc_ora        => (others=>(others=>'0')),
  adc_orb        => (others=>(others=>'0')),
  adc_ncoa       => (others=>(others=>'0')),
  adc_ncob       => (others=>(others=>'0')),
  adc_calstat    => (others=>'0'),
  rxdfeagchold   => '0',
  rxdfelfhold    => '0',
  rxdfetaphold   => '0',
  rxdfetapovrden => '0',
  rxlpmgchold    => '0',
  rxlpmhfhold    => '0',
  rxlpmlfhold    => '0',
  rxlpmoshold    => '0',
  rxoshold       => '0',
  rxcdrhold      => '0',
  fpga_sync      => '0',
  test_clksel    => (others=>'0'),
  axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
  axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

signal r   : RegType := REG_INIT_C;
signal rin : RegType;

signal clock_count : slv(15 downto 0);

begin

----------------------------------------------------------------------------------------------------
-- Frequency counter
----------------------------------------------------------------------------------------------------
sip_freq_cnt16_inst : entity work.axi_freq_cnt16
port map (
  refClk          => axilClk,
  refRst          => axilRst,
  cntRst          => '0',
  test_clocks     => test_clocks,
  clock_select    => r.test_clksel,
  clock_count     => clock_count );
  
comb: process (r, axilRst, axilReadMaster, axilWriteMaster,
               prsnt_m2c_l, pg_m2c, firefly_int, status, adc_valid,
               adc_ora, adc_orb, adc_calstat, clock_count ) is
  variable v : RegType;
  variable ep : AxiLiteEndpointType;
begin
  v := r;
  
  v.sw_trigger := '0';
  v.status     := status;
  v.adc_valid  := adc_valid;
  v.adc_ora    := adc_ora;
  v.adc_orb    := adc_orb;
  v.adc_calstat:= adc_calstat;
  
  axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

  axiSlaveRegisterR ( ep, ADDR_FMC_INFO, 0, prsnt_m2c_l );
  axiSlaveRegisterR ( ep, ADDR_FMC_INFO, 1, pg_m2c );

  axiSlaveRegister( ep, ADDR_TRANSCEIVER, 0, v.xcvr_rxrst      );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER, 1, v.sysref_sync_en  );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER, 4, v.align_enable    );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER, 8, v.rxdfeagchold    );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER, 9, v.rxdfelfhold     );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,10, v.rxdfetaphold    );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,11, v.rxlpmgchold     );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,12, v.rxlpmhfhold     );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,13, v.rxlpmlfhold     );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,14, v.rxlpmoshold     );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,15, v.rxoshold        );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,16, v.rxcdrhold       );
  axiSlaveRegister( ep, ADDR_TRANSCEIVER,17, v.rxdfetapovrden  );

  axiSlaveRegisterR( ep, ADDR_STATUS, 0, v.status );
  axiSlaveRegisterR( ep, ADDR_ADC_VAL, 0, v.adc_valid );
  
  axiSlaveRegister( ep, ADDR_SCRAMBLE, 0, v.scrambling_en );

  axiSlaveRegister( ep, ADDR_SW_TRIGGER, 0, v.sw_trigger );
  axiSlaveRegister( ep, ADDR_SW_TRIGGER, 4, v.sw_trigger_en );
  axiSlaveRegister( ep, ADDR_SW_TRIGGER, 8, v.hw_trigger_en );

  axiSlaveRegister( ep, ADDR_LMFC_CNT, 0, v.k_lmfc_cnt );

  axiSlaveRegister( ep, ADDR_F_ALIGN_CHAR, 0, v.f_align_char );

  axiSlaveRegister( ep, ADDR_ADC_PINS, 0, v.fpga_sync );
  axiSlaveRegister( ep, ADDR_ADC_PINS, 8, v.adc_ncoa(0) );
  axiSlaveRegister( ep, ADDR_ADC_PINS,10, v.adc_ncob(0) );
  axiSlaveRegister( ep, ADDR_ADC_PINS,12, v.adc_ncoa(1) );
  axiSlaveRegister( ep, ADDR_ADC_PINS,14, v.adc_ncob(1) );

  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R, 0, r.adc_ora(0) );
  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R, 2, r.adc_orb(0) );
  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R, 4, r.adc_ora(1) );
  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R, 6, r.adc_orb(1) );
  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R,16, r.adc_calstat );
  axiSlaveRegisterR( ep, ADDR_ADC_PINS_R,18, firefly_int );

  axiSlaveRegister ( ep, ADDR_TEST_CLKSEL, 0, v.test_clksel );
  axiSlaveRegisterR( ep, ADDR_TEST_CLKFRQ, 0, clock_count );
  
  axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

  if (axilRst = '1') then
    v := REG_INIT_C;
  end if;

  rin <= v;
  
  adc_ncoa       <= r.adc_ncoa;
  adc_ncob       <= r.adc_ncob;
  fpga_sync_out  <= r.fpga_sync;
  axilWriteSlave <= r.axilWriteSlave;
  axilReadSlave  <= r.axilReadSlave;
  
end process comb;

seq: process ( axilClk ) is
begin
  if rising_edge ( axilClk ) then
    r <= rin;
  end if;
end process seq;

U_SyncSwTrigger : entity surf.SynchronizerOneShot
  port map ( clk     => rx_clk,
             dataIn  => r.sw_trigger,
             dataOut => sw_trigger );

U_SyncReg : entity surf.SynchronizerVector
  generic map ( WIDTH_G => 16 )
  port map ( clk     => rx_clk,
             dataIn (0) => r.sw_trigger_en,
             dataIn (1) => r.hw_trigger_en,
             dataIn (2) => r.scrambling_en,
             dataIn (10 downto  3) => r.f_align_char,
             dataIn (15 downto 11) => r.k_lmfc_cnt,
             dataOut(0) => sw_trigger_en,
             dataOut(1) => hw_trigger_en,
             dataOut(2) => scrambling_en,
             dataOut(10 downto  3) => f_align_char,
             dataOut(15 downto 11) => k_lmfc_cnt );

U_SyncSysRef : entity surf.Synchronizer
  port map ( clk     => clk320,
             dataIn  => r.sysref_sync_en,
             dataOut => sysref_sync_en );

xcvr_rxrst      <= r.xcvr_rxrst or axilRst or rst_rxclk;
align_enable    <= r.align_enable;
rxdfeagchold    <= r.rxdfeagchold;
rxdfelfhold     <= r.rxdfelfhold;
rxdfetaphold    <= r.rxdfetaphold;
rxlpmgchold     <= r.rxlpmgchold;
rxlpmhfhold     <= r.rxlpmhfhold;
rxlpmlfhold     <= r.rxlpmlfhold;
rxlpmoshold     <= r.rxlpmoshold;
rxoshold        <= r.rxoshold;
rxcdrhold       <= r.rxcdrhold;
rxdfetapovrden  <= r.rxdfetapovrden;

--******************************************************************************************
end fmc_ctrl_syn;
--******************************************************************************************
