-------------------------------------------------------------------------------------
-- FILE NAME : xcvr_wrapper.vhd
-- AUTHOR    : John Gasco
-- COMPANY   : Abaco
-- UNITS     : Entity       - toplevel_template
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : May 10, 2017
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- Wrapper for generated IP from xilinx
--
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;

Library UNISIM;
  use UNISIM.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity xcvr_wrapper is
port (
  clk_in                     : in  sl;
  rst_in                     : in  sl;
  xcvr_status                : out slv(31 downto 0);
  xcvr_rdy_out               : out slv(15 downto 0);
  qpll_lock                  : out slv(3 downto 0);
  align_enable               : in  sl;
  rxdfeagchold_in            : in  sl;
  rxdfelfhold_in             : in  sl;
  rxdfetaphold_in            : in  sl;
  rxdfetapovrden_in          : in  sl;
  rxlpmgchold_in             : in  sl;
  rxlpmhfhold_in             : in  sl;
  rxlpmlfhold_in             : in  sl;
  rxlpmoshold_in             : in  sl;
  rxoshold_in                : in  sl;
  rxcdrhold_in               : in  sl;
  sysref_pulse               : in  sl;
  sysref_sync_en             : in  sl;

  -- RX interface
  rx_clk_out                 : out sl;
  rx_data_out                : out Slv64Array(15 downto 0);
  rx_kchar_out               : out Slv8Array (15 downto 0);
  rx_disparity_out           : out Slv8Array (15 downto 0);
  rx_invalid_out             : out Slv8Array (15 downto 0);

  -- External signals
  rxn_in                     : in  slv(15 downto 0);
  rxp_in                     : in  slv(15 downto 0);
  refclk_n                   : in  slv(3 downto 0);
  refclk_p                   : in  slv(3 downto 0);
  gtrefclk00_out             : out slv(3 downto 0)
);
end xcvr_wrapper;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of xcvr_wrapper is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant MGT_LANES                  : natural := 16;


-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal xcvr_rx_data                 : Slv64Array(15 downto 0);
signal xcvr_k                       : Slv8Array (15 downto 0);
signal xcvr_disparity               : Slv8Array (15 downto 0);
signal xcvr_invalid                 : Slv8Array (15 downto 0);
signal gtwiz_userdata_rx_out        : slv(1023 downto 0);
signal rxpmaresetdone_out           : slv(15 downto 0);
signal txpmaresetdone_out           : slv(15 downto 0);
signal rxctrl0_out                  : slv(255 downto 0);
signal rxctrl1_out                  : slv(255 downto 0);
signal rxctrl3_out                  : slv(127 downto 0);
signal gtrefclk00_in                : slv(3 downto 0);
signal qpll0lock_out                : slv(3 downto 0);
signal alignment_done               : slv(15 downto 0);
signal s_rxbyte_aligned_ff          : slv(15 downto 0) := (others => '0');
signal s_align_ena_ff               : slv(1 downto 0)  := (others => '0');

signal gtrefclk00_out_pre           : slv(3 downto 0);
signal gtrefclk00_out_sig           : slv(3 downto 0);
signal gtrefclk00_out_div2          : sl;
signal txusrclk_in                  : slv(15 downto 0);
signal txusrclk2_in                 : slv(15 downto 0);
signal rxusrclk_in                  : slv(15 downto 0);
signal rxusrclk2_in                 : slv(15 downto 0);

signal userclk_tx_active_in         : sl;
signal userclk_rx_active_in         : sl;

signal eyescanreset_int             : slv(15 downto 0);
signal rxrate_int                   : slv(47 downto 0);
signal txdiffctrl_int               : slv(63 downto 0);
signal txprecursor_int              : slv(79 downto 0);
signal txpostcursor_int             : slv(79 downto 0);
signal rxlpmen_int                  : slv(15 downto 0);

signal drpaddr_int                  : slv(143 downto 0);
signal drpdi_int                    : slv(255 downto 0);
signal drprdy_int                   : slv(15 downto 0);
signal drpen_int                    : slv(15 downto 0);
signal drpwe_int                    : slv(15 downto 0);
signal drpclk_int                   : slv(15 downto 0);
signal drpdo_int                    : slv(255 downto 0);

signal div_reset                    : sl;

-------------------------------------------------------------------------------------
-- COMPONENTS
-------------------------------------------------------------------------------------
COMPONENT xcvr_fmc134
  PORT (
    gtwiz_userclk_tx_active_in : IN SLV(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_all_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN SLV(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT SLV(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT SLV(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT SLV(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN SLV(511 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT SLV(1023 DOWNTO 0);
    gtrefclk00_in : IN SLV(3 DOWNTO 0);
    qpll0lock_out : OUT SLV(3 DOWNTO 0);
    qpll0outclk_out : OUT SLV(3 DOWNTO 0);
    qpll0outrefclk_out : OUT SLV(3 DOWNTO 0);
    drpaddr_in : IN SLV(143 DOWNTO 0);
    drpclk_in : IN SLV(15 DOWNTO 0);
    drpdi_in : IN SLV(255 DOWNTO 0);
    drpen_in : IN SLV(15 DOWNTO 0);
    drpwe_in : IN SLV(15 DOWNTO 0);
    eyescanreset_in : IN SLV(15 DOWNTO 0);
    gthrxn_in : IN SLV(15 DOWNTO 0);
    gthrxp_in : IN SLV(15 DOWNTO 0);
    rx8b10ben_in : IN SLV(15 DOWNTO 0);
    rxcdrhold_in : IN SLV(15 DOWNTO 0);
    rxcommadeten_in : IN SLV(15 DOWNTO 0);
    rxdfeagchold_in : IN SLV(15 DOWNTO 0);
    rxdfelfhold_in : IN SLV(15 DOWNTO 0);
    rxdfetap10hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap10ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap11hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap11ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap12hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap12ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap13hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap13ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap14hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap14ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap15hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap15ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap2hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap2ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap3hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap3ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap4hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap4ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap5hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap5ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap6hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap6ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap7hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap7ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap8hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap8ovrden_in : IN SLV(15 DOWNTO 0);
    rxdfetap9hold_in : IN SLV(15 DOWNTO 0);
    rxdfetap9ovrden_in : IN SLV(15 DOWNTO 0);
    rxlpmen_in : IN SLV(15 DOWNTO 0);
    rxlpmgchold_in : IN SLV(15 DOWNTO 0);
    rxlpmhfhold_in : IN SLV(15 DOWNTO 0);
    rxlpmlfhold_in : IN SLV(15 DOWNTO 0);
    rxlpmoshold_in : IN SLV(15 DOWNTO 0);
    rxmcommaalignen_in : IN SLV(15 DOWNTO 0);
    rxoshold_in : IN SLV(15 DOWNTO 0);
    rxpcommaalignen_in : IN SLV(15 DOWNTO 0);
    rxrate_in : IN SLV(47 DOWNTO 0);
    rxusrclk_in : IN SLV(15 DOWNTO 0);
    rxusrclk2_in : IN SLV(15 DOWNTO 0);
    txdiffctrl_in : IN SLV(63 DOWNTO 0);
    txpostcursor_in : IN SLV(79 DOWNTO 0);
    txprecursor_in : IN SLV(79 DOWNTO 0);
    txusrclk_in : IN SLV(15 DOWNTO 0);
    txusrclk2_in : IN SLV(15 DOWNTO 0);
    drpdo_out : OUT SLV(255 DOWNTO 0);
    drprdy_out : OUT SLV(15 DOWNTO 0);
    gthtxn_out : OUT SLV(15 DOWNTO 0);
    gthtxp_out : OUT SLV(15 DOWNTO 0);
    rxbyteisaligned_out : OUT SLV(15 DOWNTO 0);
    rxbyterealign_out : OUT SLV(15 DOWNTO 0);
    rxcommadet_out : OUT SLV(15 DOWNTO 0);
    rxctrl0_out : OUT SLV(255 DOWNTO 0);
    rxctrl1_out : OUT SLV(255 DOWNTO 0);
    rxctrl2_out : OUT SLV(127 DOWNTO 0);
    rxctrl3_out : OUT SLV(127 DOWNTO 0);
    rxoutclk_out : OUT SLV(15 DOWNTO 0);
    rxpmaresetdone_out : OUT SLV(15 DOWNTO 0);
    txoutclk_out : OUT SLV(15 DOWNTO 0);
    txpmaresetdone_out : OUT SLV(15 DOWNTO 0)
  );
END COMPONENT;

COMPONENT in_system_ibert_0
  PORT (
    drpclk_o : OUT SLV(15 DOWNTO 0);
    gt0_drpen_o : OUT SL;
    gt0_drpwe_o : OUT SL;
    gt0_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt0_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt0_drprdy_i : IN SL;
    gt0_drpdo_i : IN SLV(15 DOWNTO 0);
    gt1_drpen_o : OUT SL;
    gt1_drpwe_o : OUT SL;
    gt1_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt1_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt1_drprdy_i : IN SL;
    gt1_drpdo_i : IN SLV(15 DOWNTO 0);
    gt2_drpen_o : OUT SL;
    gt2_drpwe_o : OUT SL;
    gt2_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt2_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt2_drprdy_i : IN SL;
    gt2_drpdo_i : IN SLV(15 DOWNTO 0);
    gt3_drpen_o : OUT SL;
    gt3_drpwe_o : OUT SL;
    gt3_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt3_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt3_drprdy_i : IN SL;
    gt3_drpdo_i : IN SLV(15 DOWNTO 0);
    gt4_drpen_o : OUT SL;
    gt4_drpwe_o : OUT SL;
    gt4_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt4_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt4_drprdy_i : IN SL;
    gt4_drpdo_i : IN SLV(15 DOWNTO 0);
    gt5_drpen_o : OUT SL;
    gt5_drpwe_o : OUT SL;
    gt5_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt5_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt5_drprdy_i : IN SL;
    gt5_drpdo_i : IN SLV(15 DOWNTO 0);
    gt6_drpen_o : OUT SL;
    gt6_drpwe_o : OUT SL;
    gt6_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt6_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt6_drprdy_i : IN SL;
    gt6_drpdo_i : IN SLV(15 DOWNTO 0);
    gt7_drpen_o : OUT SL;
    gt7_drpwe_o : OUT SL;
    gt7_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt7_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt7_drprdy_i : IN SL;
    gt7_drpdo_i : IN SLV(15 DOWNTO 0);
    gt8_drpen_o : OUT SL;
    gt8_drpwe_o : OUT SL;
    gt8_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt8_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt8_drprdy_i : IN SL;
    gt8_drpdo_i : IN SLV(15 DOWNTO 0);
    gt9_drpen_o : OUT SL;
    gt9_drpwe_o : OUT SL;
    gt9_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt9_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt9_drprdy_i : IN SL;
    gt9_drpdo_i : IN SLV(15 DOWNTO 0);
    gt10_drpen_o : OUT SL;
    gt10_drpwe_o : OUT SL;
    gt10_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt10_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt10_drprdy_i : IN SL;
    gt10_drpdo_i : IN SLV(15 DOWNTO 0);
    gt11_drpen_o : OUT SL;
    gt11_drpwe_o : OUT SL;
    gt11_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt11_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt11_drprdy_i : IN SL;
    gt11_drpdo_i : IN SLV(15 DOWNTO 0);
    gt12_drpen_o : OUT SL;
    gt12_drpwe_o : OUT SL;
    gt12_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt12_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt12_drprdy_i : IN SL;
    gt12_drpdo_i : IN SLV(15 DOWNTO 0);
    gt13_drpen_o : OUT SL;
    gt13_drpwe_o : OUT SL;
    gt13_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt13_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt13_drprdy_i : IN SL;
    gt13_drpdo_i : IN SLV(15 DOWNTO 0);
    gt14_drpen_o : OUT SL;
    gt14_drpwe_o : OUT SL;
    gt14_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt14_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt14_drprdy_i : IN SL;
    gt14_drpdo_i : IN SLV(15 DOWNTO 0);
    gt15_drpen_o : OUT SL;
    gt15_drpwe_o : OUT SL;
    gt15_drpaddr_o : OUT SLV(8 DOWNTO 0);
    gt15_drpdi_o : OUT SLV(15 DOWNTO 0);
    gt15_drprdy_i : IN SL;
    gt15_drpdo_i : IN SLV(15 DOWNTO 0);
    eyescanreset_o : OUT SLV(15 DOWNTO 0);
    rxrate_o : OUT SLV(47 DOWNTO 0);
    txdiffctrl_o : OUT SLV(63 DOWNTO 0);
    txprecursor_o : OUT SLV(79 DOWNTO 0);
    txpostcursor_o : OUT SLV(79 DOWNTO 0);
    rxlpmen_o : OUT SLV(15 DOWNTO 0);
    rxoutclk_i : IN SLV(15 DOWNTO 0);
    clk : IN SL
  );
END COMPONENT;

--***********************************************************************************
begin
--***********************************************************************************

-------------------------------------------------------------------------------------
-- Xilinx GTH Transceiver
-------------------------------------------------------------------------------------
xcvr_fmc134_inst : xcvr_fmc134
port map (
  gtwiz_reset_clk_freerun_in(0)         => clk_in,
  gtwiz_reset_all_in(0)                 => rst_in,

  gtrefclk00_in                         => gtrefclk00_in(0) & gtrefclk00_in(1) & gtrefclk00_in(2) & gtrefclk00_in(3),
  qpll0lock_out                         => qpll0lock_out,
  qpll0outclk_out                       => open,
  qpll0outrefclk_out                    => open,

  txusrclk_in                           => txusrclk_in,
  txusrclk2_in                          => txusrclk2_in,
  txoutclk_out                          => open,
  gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
  gtwiz_reset_tx_datapath_in(0)         => '0',
  gtwiz_userclk_tx_active_in(0)         => userclk_tx_active_in,
  gtwiz_reset_tx_done_out               => open,
  gtwiz_userdata_tx_in                  => (others => '0'),

  rxdfeagchold_in                       => (others => rxdfeagchold_in   ),
  rxdfelfhold_in                        => (others => rxdfelfhold_in    ),
  rxdfetap2hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap3hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap4hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap5hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap6hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap7hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap8hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap9hold_in                      => (others => rxdfetaphold_in   ),
  rxdfetap10hold_in                     => (others => rxdfetaphold_in   ),
  rxdfetap11hold_in                     => (others => rxdfetaphold_in   ),
  rxdfetap12hold_in                     => (others => rxdfetaphold_in   ),
  rxdfetap13hold_in                     => (others => rxdfetaphold_in   ),
  rxdfetap14hold_in                     => (others => rxdfetaphold_in   ),
  rxdfetap15hold_in                     => (others => rxdfetaphold_in   ),

  rxdfetap2ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap3ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap4ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap5ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap6ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap7ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap8ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap9ovrden_in                    => (others => rxdfetapovrden_in ),
  rxdfetap10ovrden_in                   => (others => rxdfetapovrden_in ),
  rxdfetap11ovrden_in                   => (others => rxdfetapovrden_in ),
  rxdfetap12ovrden_in                   => (others => rxdfetapovrden_in ),
  rxdfetap13ovrden_in                   => (others => rxdfetapovrden_in ),
  rxdfetap14ovrden_in                   => (others => rxdfetapovrden_in ),
  rxdfetap15ovrden_in                   => (others => rxdfetapovrden_in ),

  rxlpmgchold_in                        => (others => rxlpmgchold_in    ),
  rxlpmhfhold_in                        => (others => rxlpmhfhold_in    ),
  rxlpmlfhold_in                        => (others => rxlpmlfhold_in    ),
  rxlpmoshold_in                        => (others => rxlpmoshold_in    ),
  rxoshold_in                           => (others => rxoshold_in       ),
  rxcdrhold_in                          => (others => rxcdrhold_in      ),

  drpaddr_in                            => drpaddr_int,
  drpclk_in                             => drpclk_int,
  drpdi_in                              => drpdi_int,
  drpen_in                              => drpen_int,
  drpwe_in                              => drpwe_int,
  drpdo_out                             => drpdo_int,
  drprdy_out                            => drprdy_int,
  eyescanreset_in                       => eyescanreset_int,
  rxrate_in                             => rxrate_int,
  txdiffctrl_in                         => txdiffctrl_int,
  txprecursor_in                        => txprecursor_int,
  txpostcursor_in                       => txpostcursor_int,
  rxlpmen_in                            => rxlpmen_int,

  gthtxn_out                            => open,
  gthtxp_out                            => open,

  rxusrclk_in                           => rxusrclk_in,
  rxusrclk2_in                          => rxusrclk2_in,
  rxoutclk_out                          => open,
  gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
  gtwiz_reset_rx_datapath_in(0)         => '0',
  gtwiz_userclk_rx_active_in(0)         => userclk_rx_active_in,
  gtwiz_reset_rx_cdr_stable_out         => open,
  gtwiz_reset_rx_done_out               => open,
  gtwiz_userdata_rx_out                 => gtwiz_userdata_rx_out,

  gthrxn_in                             => rxn_in,
  gthrxp_in                             => rxp_in,
  rx8b10ben_in                          => (others => '1'),
  rxcommadeten_in                       => (others => '1'),
  rxmcommaalignen_in                    => not(s_rxbyte_aligned_ff),
  rxpcommaalignen_in                    => not(s_rxbyte_aligned_ff),
  rxbyteisaligned_out                   => alignment_done,
  rxbyterealign_out                     => open,
  rxcommadet_out                        => open,
  rxctrl0_out                           => rxctrl0_out, -- HIGH when K character
  rxctrl1_out                           => rxctrl1_out, -- HIGH when disparity error
  rxctrl2_out                           => open,        -- HIGH when Comma Character
  rxctrl3_out                           => rxctrl3_out, -- HIGH when invalid character

  rxpmaresetdone_out                    => rxpmaresetdone_out,
  txpmaresetdone_out                    => txpmaresetdone_out

);

qpll_lock  <= qpll0lock_out;
rx_clk_out <= gtrefclk00_out_div2;

g_userclk_gen: for i in 0 to 15 generate
  txusrclk_in(i)  <= gtrefclk00_out_sig(0);
  rxusrclk_in(i)  <= gtrefclk00_out_sig(0);
  txusrclk2_in(i) <= gtrefclk00_out_div2;
  rxusrclk2_in(i) <= gtrefclk00_out_div2;
end generate;

-------------------------------------------------------------------------------------
-- RX Interface
-------------------------------------------------------------------------------------
gen_rx_interface : for index in 0 to (MGT_LANES - 1) generate

  xcvr_rdy_out(index) <= rxpmaresetdone_out(index) and s_rxbyte_aligned_ff(index);
  xcvr_status(index)  <= rxpmaresetdone_out(index);

  process(gtrefclk00_out_div2)
  begin
    if rising_edge(gtrefclk00_out_div2) then
      xcvr_rx_data(index)    <=  gtwiz_userdata_rx_out((64*(index+1))-1 downto 64*index);
      xcvr_k(index)          <=  rxctrl0_out((16*(index+1))-9 downto 16*index); -- we got k char
      xcvr_disparity(index)  <=  rxctrl1_out((16*(index+1))-9 downto 16*index); -- we got disparity error
      xcvr_invalid(index)    <=  rxctrl3_out(( 8*(index+1))-1 downto  8*index); -- we got an invalid character
    end if;
  end process;

end generate;

userclk_rx_active_in      <= and_reduce(rxpmaresetdone_out);
userclk_tx_active_in      <= and_reduce(txpmaresetdone_out);

-------------------------------------------------------------------------------------
-- Multi-gigabit Transceiver Clocking
-- All BUFG_GT CLR pins are connected to div_reset, but the CLRMASK input is used
-- so that div_reset is only passed to the RefClk_BUFG_Div2 BUFG_GT.
-------------------------------------------------------------------------------------
gen_refclk : for index in 0 to 3 generate

  IBUFDS_GTE3_inst : IBUFDS_GTE3
  generic map (
    REFCLK_HROW_CK_SEL => "00"
  )
  port map (
    O     => gtrefclk00_in(index),
    ODIV2 => gtrefclk00_out_pre(index),
    CEB   => '0',
    I     => refclk_p(index),
    IB    => refclk_n(index)
  );

  RefClk_BUFG : BUFG_GT
  port map (
    O       => gtrefclk00_out_sig(index),
    I       => gtrefclk00_out_pre(index),
    CE      => '1',
    CEMASK  => '0',
    CLR     => div_reset,
    CLRMASK => '1',
    DIV     => "000"
  );

end generate;

RefClk_BUFG_Div2 : BUFG_GT
port map (
  O       => gtrefclk00_out_div2,
  I       => gtrefclk00_out_pre(0),
  CE      => '1',
  CEMASK  => '0',
  CLR     => div_reset,
  CLRMASK => '0',
  DIV     => "001"
);

gtrefclk00_out <= gtrefclk00_out_sig;

-------------------------------------------------------------------------------------
-- BUFG_GT divider reset
-- This reset is used to sync the divide-by-2 clock with sysref. This is necessary
-- to achieve deterministic latency and multi-FPGA synchronization.
--
-- When sysref_sync_en is '1', sysref pulses are passed to div_reset. If
-- sysref_sync_en deasserts when sysref_pulse is asserted, div_reset will deassert
-- after sysref_pulse goes low.
-------------------------------------------------------------------------------------
div_reset_sync : process(gtrefclk00_out_sig(0))
begin
  if rising_edge(gtrefclk00_out_sig(0)) then
    if sysref_sync_en = '1' then
      div_reset <= sysref_pulse;
    elsif sysref_sync_en = '0' and sysref_pulse = '0' then
      div_reset <= '0';
    end if;
  end if;
end process;

-------------------------------------------------------------------------------------
-- Bit alignment
-- The FPGA transceivers take care of the bit alignment by detecting the /K/ = K25.8
-- character (0xBC) and aligning the serial stream to that known character. When that
-- happens, the flags are captured at s_rxbyte_aligned_ff.
-------------------------------------------------------------------------------------
process(gtrefclk00_out_div2)
begin
  if rising_edge(gtrefclk00_out_div2) then
    s_align_ena_ff(0) <= align_enable;
    s_align_ena_ff(1) <= s_align_ena_ff(0);

    if (s_align_ena_ff(1) = '0') then
      s_rxbyte_aligned_ff <= (others => '0');
    else
      for index in 0 to (MGT_LANES - 1) loop
        if ((alignment_done(index) = '1') and (s_rxbyte_aligned_ff(index) = '0')) then
          s_rxbyte_aligned_ff(index) <= '1';
        end if;
      end loop;
    end if;
  end if;
end process;

-------------------------------------------------------------------------------------
-- JESD204B ADC bit swapping for PC820 HSPC site
-------------------------------------------------------------------------------------
-- The high speed bit lanes coming from the FMC134 ADCs are routed to certain FPGA pins. These pins
-- are bounded to specific High Speed Transceivers (GTH). However, the Vivado tool indexes the bits
-- automatically depending on the physical location of those GTHs. From PG182 UltraScale FPGAs
-- Transceivers Wizard v1.6:
--
-- "The width of each port scales with the number of transceiver common primitives
-- instantiated within the core instance. The least significant bit(s) correspond to the first
-- enabled transceiver common primitive in increasing grid order, where the Y axis increments
-- before X."
--
-- The following table shows the physical connection of the FPGA pins, the High speed transceivers
-- location (and its automatic bit indexing) and the required bit order by the JESD204B core:
--
-- ||                                 ADC                                 ||
-- || LANE NAME || FPGA PIN || GTH LOC || BIT ORDER || JESD204B BIT ORDER ||
-- -------------------------------------------------------------------------
-- ||  ADC0_DA0 ||          ||   X1Y31 ||    15    --->         0         ||
-- ||  ADC0_DA1 ||          ||   X1Y30 ||    14    --->         1         ||
-- ||  ADC0_DA2 ||          ||   X1Y29 ||    13    --->         2         ||
-- ||  ADC0_DA3 ||          ||   X1Y28 ||    12    --->         3         ||
-- ||  ADC0_DB0 ||          ||   X1Y24 ||     8    --->         4         ||
-- ||  ADC0_DB1 ||          ||   X1Y25 ||     9    --->         5         ||
-- ||  ADC0_DB2 ||          ||   X1Y26 ||    10    --->         6         ||
-- ||  ADC0_DB3 ||          ||   X1Y27 ||    11    --->         7         ||
-- ||  ADC1_DA0 ||          ||   X1Y19 ||     7    --->         8         ||
-- ||  ADC1_DA1 ||          ||   X1Y18 ||     6    --->         9         ||
-- ||  ADC1_DA2 ||          ||   X1Y17 ||     5    --->        10         ||
-- ||  ADC1_DA3 ||          ||   X1Y16 ||     4    --->        11         ||
-- ||  ADC1_DB0 ||          ||   X1Y15 ||     3    --->        12         ||
-- ||  ADC1_DB1 ||          ||   X1Y14 ||     2    --->        13         ||
-- ||  ADC1_DB2 ||          ||   X1Y13 ||     1    --->        14         ||
-- ||  ADC1_DB3 ||          ||   X1Y12 ||     0    --->        15         ||
-- -------------------------------------------------------------------------

rx_data_out(0)            <= xcvr_rx_data(15);
rx_data_out(1)            <= xcvr_rx_data(14);
rx_data_out(2)            <= xcvr_rx_data(13);
rx_data_out(3)            <= xcvr_rx_data(12);
rx_data_out(4)            <= xcvr_rx_data(8);
rx_data_out(5)            <= xcvr_rx_data(9);
rx_data_out(6)            <= xcvr_rx_data(10);
rx_data_out(7)            <= xcvr_rx_data(11);
rx_data_out(8)            <= xcvr_rx_data(7);
rx_data_out(9)            <= xcvr_rx_data(6);
rx_data_out(10)           <= xcvr_rx_data(5);
rx_data_out(11)           <= xcvr_rx_data(4);
rx_data_out(12)           <= xcvr_rx_data(3);
rx_data_out(13)           <= xcvr_rx_data(2);
rx_data_out(14)           <= xcvr_rx_data(1);
rx_data_out(15)           <= xcvr_rx_data(0);

rx_kchar_out(0)           <= xcvr_k(15);
rx_kchar_out(1)           <= xcvr_k(14);
rx_kchar_out(2)           <= xcvr_k(13);
rx_kchar_out(3)           <= xcvr_k(12);
rx_kchar_out(4)           <= xcvr_k(8);
rx_kchar_out(5)           <= xcvr_k(9);
rx_kchar_out(6)           <= xcvr_k(10);
rx_kchar_out(7)           <= xcvr_k(11);
rx_kchar_out(8)           <= xcvr_k(7);
rx_kchar_out(9)           <= xcvr_k(6);
rx_kchar_out(10)          <= xcvr_k(5);
rx_kchar_out(11)          <= xcvr_k(4);
rx_kchar_out(12)          <= xcvr_k(3);
rx_kchar_out(13)          <= xcvr_k(2);
rx_kchar_out(14)          <= xcvr_k(1);
rx_kchar_out(15)          <= xcvr_k(0);

rx_disparity_out(0)       <= xcvr_disparity(15);
rx_disparity_out(1)       <= xcvr_disparity(14);
rx_disparity_out(2)       <= xcvr_disparity(13);
rx_disparity_out(3)       <= xcvr_disparity(12);
rx_disparity_out(4)       <= xcvr_disparity(8);
rx_disparity_out(5)       <= xcvr_disparity(9);
rx_disparity_out(6)       <= xcvr_disparity(10);
rx_disparity_out(7)       <= xcvr_disparity(11);
rx_disparity_out(8)       <= xcvr_disparity(7);
rx_disparity_out(9)       <= xcvr_disparity(6);
rx_disparity_out(10)      <= xcvr_disparity(5);
rx_disparity_out(11)      <= xcvr_disparity(4);
rx_disparity_out(12)      <= xcvr_disparity(3);
rx_disparity_out(13)      <= xcvr_disparity(2);
rx_disparity_out(14)      <= xcvr_disparity(1);
rx_disparity_out(15)      <= xcvr_disparity(0);

rx_invalid_out(0)         <= xcvr_invalid(15);
rx_invalid_out(1)         <= xcvr_invalid(14);
rx_invalid_out(2)         <= xcvr_invalid(13);
rx_invalid_out(3)         <= xcvr_invalid(12);
rx_invalid_out(4)         <= xcvr_invalid(8);
rx_invalid_out(5)         <= xcvr_invalid(9);
rx_invalid_out(6)         <= xcvr_invalid(10);
rx_invalid_out(7)         <= xcvr_invalid(11);
rx_invalid_out(8)         <= xcvr_invalid(7);
rx_invalid_out(9)         <= xcvr_invalid(6);
rx_invalid_out(10)        <= xcvr_invalid(5);
rx_invalid_out(11)        <= xcvr_invalid(4);
rx_invalid_out(12)        <= xcvr_invalid(3);
rx_invalid_out(13)        <= xcvr_invalid(2);
rx_invalid_out(14)        <= xcvr_invalid(1);
rx_invalid_out(15)        <= xcvr_invalid(0);

xcvr_status(16)           <= s_rxbyte_aligned_ff(12);
xcvr_status(17)           <= s_rxbyte_aligned_ff(8);
xcvr_status(18)           <= s_rxbyte_aligned_ff(4);
xcvr_status(19)           <= s_rxbyte_aligned_ff(0);
xcvr_status(20)           <= qpll0lock_out(3);
xcvr_status(21)           <= qpll0lock_out(2);
xcvr_status(22)           <= qpll0lock_out(1);
xcvr_status(23)           <= qpll0lock_out(0);
xcvr_status(31 downto 24) <= (others=>'0');

-------------------------------------------------------------------------------------
-- In System IBERT
-------------------------------------------------------------------------------------
in_system_ibert : in_system_ibert_0
  PORT MAP (
    drpclk_o          => drpclk_int,
    gt0_drpen_o       => drpen_int(0),
    gt0_drpwe_o       => drpwe_int(0),
    gt0_drpaddr_o     => drpaddr_int(8 downto 0),
    gt0_drpdi_o       => drpdi_int(15 downto 0),
    gt0_drprdy_i      => drprdy_int(0),
    gt0_drpdo_i       => drpdo_int(15 downto 0),
    gt1_drpen_o       => drpen_int(1),
    gt1_drpwe_o       => drpwe_int(1),
    gt1_drpaddr_o     => drpaddr_int(17 downto 9),
    gt1_drpdi_o       => drpdi_int(31 downto 16),
    gt1_drprdy_i      => drprdy_int(1),
    gt1_drpdo_i       => drpdo_int(31 downto 16),
    gt2_drpen_o       => drpen_int(2),
    gt2_drpwe_o       => drpwe_int(2),
    gt2_drpaddr_o     => drpaddr_int(26 downto 18),
    gt2_drpdi_o       => drpdi_int(47 downto 32),
    gt2_drprdy_i      => drprdy_int(2),
    gt2_drpdo_i       => drpdo_int(47 downto 32),
    gt3_drpen_o       => drpen_int(3),
    gt3_drpwe_o       => drpwe_int(3),
    gt3_drpaddr_o     => drpaddr_int(35 downto 27),
    gt3_drpdi_o       => drpdi_int(63 downto 48),
    gt3_drprdy_i      => drprdy_int(3),
    gt3_drpdo_i       => drpdo_int(63 downto 48),
    gt4_drpen_o       => drpen_int(4),
    gt4_drpwe_o       => drpwe_int(4),
    gt4_drpaddr_o     => drpaddr_int(44 downto 36),
    gt4_drpdi_o       => drpdi_int(79 downto 64),
    gt4_drprdy_i      => drprdy_int(4),
    gt4_drpdo_i       => drpdo_int(79 downto 64),
    gt5_drpen_o       => drpen_int(5),
    gt5_drpwe_o       => drpwe_int(5),
    gt5_drpaddr_o     => drpaddr_int(53 downto 45),
    gt5_drpdi_o       => drpdi_int(95 downto 80),
    gt5_drprdy_i      => drprdy_int(5),
    gt5_drpdo_i       => drpdo_int(95 downto 80),
    gt6_drpen_o       => drpen_int(6),
    gt6_drpwe_o       => drpwe_int(6),
    gt6_drpaddr_o     => drpaddr_int(62 downto 54),
    gt6_drpdi_o       => drpdi_int(111 downto 96),
    gt6_drprdy_i      => drprdy_int(6),
    gt6_drpdo_i       => drpdo_int(111 downto 96),
    gt7_drpen_o       => drpen_int(7),
    gt7_drpwe_o       => drpwe_int(7),
    gt7_drpaddr_o     => drpaddr_int(71 downto 63),
    gt7_drpdi_o       => drpdi_int(127 downto 112),
    gt7_drprdy_i      => drprdy_int(7),
    gt7_drpdo_i       => drpdo_int(127 downto 112),
    gt8_drpen_o       => drpen_int(8),
    gt8_drpwe_o       => drpwe_int(8),
    gt8_drpaddr_o     => drpaddr_int(80 downto 72),
    gt8_drpdi_o       => drpdi_int(143 downto 128),
    gt8_drprdy_i      => drprdy_int(8),
    gt8_drpdo_i       => drpdo_int(143 downto 128),
    gt9_drpen_o       => drpen_int(9),
    gt9_drpwe_o       => drpwe_int(9),
    gt9_drpaddr_o     => drpaddr_int(89 downto 81),
    gt9_drpdi_o       => drpdi_int(159 downto 144),
    gt9_drprdy_i      => drprdy_int(9),
    gt9_drpdo_i       => drpdo_int(159 downto 144),
    gt10_drpen_o      => drpen_int(10),
    gt10_drpwe_o      => drpwe_int(10),
    gt10_drpaddr_o    => drpaddr_int(98 downto 90),
    gt10_drpdi_o      => drpdi_int(175 downto 160),
    gt10_drprdy_i     => drprdy_int(10),
    gt10_drpdo_i      => drpdo_int(175 downto 160),
    gt11_drpen_o      => drpen_int(11),
    gt11_drpwe_o      => drpwe_int(11),
    gt11_drpaddr_o    => drpaddr_int(107 downto 99),
    gt11_drpdi_o      => drpdi_int(191 downto 176),
    gt11_drprdy_i     => drprdy_int(11),
    gt11_drpdo_i      => drpdo_int(191 downto 176),
    gt12_drpen_o      => drpen_int(12),
    gt12_drpwe_o      => drpwe_int(12),
    gt12_drpaddr_o    => drpaddr_int(116 downto 108),
    gt12_drpdi_o      => drpdi_int(207 downto 192),
    gt12_drprdy_i     => drprdy_int(12),
    gt12_drpdo_i      => drpdo_int(207 downto 192),
    gt13_drpen_o      => drpen_int(13),
    gt13_drpwe_o      => drpwe_int(13),
    gt13_drpaddr_o    => drpaddr_int(125 downto 117),
    gt13_drpdi_o      => drpdi_int(223 downto 208),
    gt13_drprdy_i     => drprdy_int(13),
    gt13_drpdo_i      => drpdo_int(223 downto 208),
    gt14_drpen_o      => drpen_int(14),
    gt14_drpwe_o      => drpwe_int(14),
    gt14_drpaddr_o    => drpaddr_int(134 downto 126),
    gt14_drpdi_o      => drpdi_int(239 downto 224),
    gt14_drprdy_i     => drprdy_int(14),
    gt14_drpdo_i      => drpdo_int(239 downto 224),
    gt15_drpen_o      => drpen_int(15),
    gt15_drpwe_o      => drpwe_int(15),
    gt15_drpaddr_o    => drpaddr_int(143 downto 135),
    gt15_drpdi_o      => drpdi_int(255 downto 240),
    gt15_drprdy_i     => drprdy_int(15),
    gt15_drpdo_i      => drpdo_int(255 downto 240),
    eyescanreset_o    => eyescanreset_int,
    rxrate_o          => rxrate_int,
    txdiffctrl_o      => txdiffctrl_int,
    txprecursor_o     => txprecursor_int,
    txpostcursor_o    => txpostcursor_int,
    rxlpmen_o         => rxlpmen_int,
    rxoutclk_i        => rxusrclk2_in,
    clk               => clk_in
  );

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************
