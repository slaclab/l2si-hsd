##############################
# StdLib: Custom Constraints #
##############################
#set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

#  Secondary FMC (Quad 232)
#set_property PACKAGE_PIN H8 [get_ports {pgpTxP[0]}]
#set_property PACKAGE_PIN H7 [get_ports {pgpTxN[0]}]
#set_property PACKAGE_PIN H4 [get_ports {pgpRxP[0]}]
#set_property PACKAGE_PIN H3 [get_ports {pgpRxN[0]}]
#set_property PACKAGE_PIN G6 [get_ports {pgpTxP[1]}]
#set_property PACKAGE_PIN G5 [get_ports {pgpTxN[1]}]
#set_property PACKAGE_PIN G2 [get_ports {pgpRxP[1]}]
#set_property PACKAGE_PIN G1 [get_ports {pgpRxN[1]}]
#set_property PACKAGE_PIN F8 [get_ports {pgpTxP[2]}]
#set_property PACKAGE_PIN F7 [get_ports {pgpTxN[2]}]
#set_property PACKAGE_PIN F4 [get_ports {pgpRxP[2]}]
#set_property PACKAGE_PIN F3 [get_ports {pgpRxN[2]}]
#set_property PACKAGE_PIN E6 [get_ports {pgpTxP[3]}]
#set_property PACKAGE_PIN E5 [get_ports {pgpTxN[3]}]
#set_property PACKAGE_PIN E2 [get_ports {pgpRxP[3]}]
#set_property PACKAGE_PIN E1 [get_ports {pgpRxN[3]}]
#set_property PACKAGE_PIN K8 [get_ports {pgpRefClkP}]
#set_property PACKAGE_PIN K7 [get_ports {pgpRefClkN}]
#  Firefly #1 (Quad 128)
set_property PACKAGE_PIN AJ42 [get_ports {pgpRxN[0]}]
set_property PACKAGE_PIN AJ41 [get_ports {pgpRxP[0]}]
set_property PACKAGE_PIN AH39 [get_ports {pgpTxN[0]}]
set_property PACKAGE_PIN AH38 [get_ports {pgpTxP[0]}]
set_property PACKAGE_PIN AG42 [get_ports {pgpRxN[1]}]
set_property PACKAGE_PIN AG41 [get_ports {pgpRxP[1]}]
set_property PACKAGE_PIN AF39 [get_ports {pgpTxN[1]}]
set_property PACKAGE_PIN AF38 [get_ports {pgpTxP[1]}]
set_property PACKAGE_PIN AE42 [get_ports {pgpRxN[2]}]
set_property PACKAGE_PIN AE41 [get_ports {pgpRxP[2]}]
set_property PACKAGE_PIN AD39 [get_ports {pgpTxN[2]}]
set_property PACKAGE_PIN AD38 [get_ports {pgpTxP[2]}]
set_property PACKAGE_PIN AC42 [get_ports {pgpRxN[3]}]
set_property PACKAGE_PIN AC41 [get_ports {pgpRxP[3]}]
set_property PACKAGE_PIN AB39 [get_ports {pgpTxN[3]}]
set_property PACKAGE_PIN AB38 [get_ports {pgpTxP[3]}]
#  Si5338 output 2
set_property PACKAGE_PIN AE37 [get_ports pgpRefClkN]
set_property PACKAGE_PIN AE36 [get_ports pgpRefClkP]
#  Firefly #2 (Quad 131)
set_property PACKAGE_PIN AA42 [get_ports {pgpRxN[4]}]
set_property PACKAGE_PIN AA41 [get_ports {pgpRxP[4]}]
set_property PACKAGE_PIN Y39 [get_ports {pgpTxN[4]}]
set_property PACKAGE_PIN Y38 [get_ports {pgpTxP[4]}]
set_property PACKAGE_PIN W42 [get_ports {pgpRxN[5]}]
set_property PACKAGE_PIN W41 [get_ports {pgpRxP[5]}]
set_property PACKAGE_PIN V39 [get_ports {pgpTxN[5]}]
set_property PACKAGE_PIN V38 [get_ports {pgpTxP[5]}]
set_property PACKAGE_PIN U42 [get_ports {pgpRxN[6]}]
set_property PACKAGE_PIN U41 [get_ports {pgpRxP[6]}]
set_property PACKAGE_PIN T39 [get_ports {pgpTxN[6]}]
set_property PACKAGE_PIN T38 [get_ports {pgpTxP[6]}]
set_property PACKAGE_PIN R42 [get_ports {pgpRxN[7]}]
set_property PACKAGE_PIN R41 [get_ports {pgpRxP[7]}]
set_property PACKAGE_PIN P39 [get_ports {pgpTxN[7]}]
set_property PACKAGE_PIN P38 [get_ports {pgpTxP[7]}]
#  Si5338 output 1 ( using as timingRefClk )
#set_property PACKAGE_PIN AA36 [get_ports {pgpAltClkP}]
#set_property PACKAGE_PIN AA37 [get_ports {pgpAltClkN}]

set_property PACKAGE_PIN H14 [get_ports {qsfpPrsN[0]}]
set_property PACKAGE_PIN H13 [get_ports {qsfpRstN[0]}]
set_property PACKAGE_PIN J13 [get_ports {qsfpIntN[0]}]
set_property PACKAGE_PIN F12 [get_ports {qsfpScl[0]}]
set_property PACKAGE_PIN E12 [get_ports {qsfpSda[0]}]

set_property PACKAGE_PIN G12 [get_ports {qsfpPrsN[1]}]
set_property PACKAGE_PIN F13 [get_ports {qsfpRstN[1]}]
set_property PACKAGE_PIN F14 [get_ports {qsfpIntN[1]}]
set_property PACKAGE_PIN E15 [get_ports {qsfpScl[1]}]
set_property PACKAGE_PIN F15 [get_ports {qsfpSda[1]}]

set_property PACKAGE_PIN H12 [get_ports oe_osc]

set_property IOSTANDARD LVCMOS18 [get_ports {qsfp*[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports oe_osc]
set_property PULLUP true [get_ports {qsfpPrsN[0]}]
set_property PULLUP true [get_ports {qsfpPrsN[1]}]
set_property PULLUP true [get_ports {qsfpIntN[0]}]
set_property PULLUP true [get_ports {qsfpIntN[1]}]

#set_property PACKAGE_PIN F14 [get_ports {usrClkSel}]
#set_property PACKAGE_PIN F13 [get_ports {pgpClkEn}]
#set_property PACKAGE_PIN E12 [get_ports {usrClkEn}]
#set_property PACKAGE_PIN F12 [get_ports {qsfpRstN}]

set_property PACKAGE_PIN G14 [get_ports pgpFabClkN]
set_property PACKAGE_PIN G15 [get_ports pgpFabClkP]

#set_property IOSTANDARD LVCMOS18 [get_ports {usrClkSel}]
#set_property IOSTANDARD LVCMOS18 [get_ports {pgpClkEn}]
#set_property IOSTANDARD LVCMOS18 [get_ports {usrClkEn}]
#set_property IOSTANDARD LVCMOS18 [get_ports {qsfpRstN}]

set_property IOSTANDARD LVDS [get_ports pgpFabClkP]
set_property DIFF_TERM_ADV=TERM_100 [get_ports {pgpFabClkP}]
set_property IOSTANDARD LVDS [get_ports pgpFabClkN]
set_property DIFF_TERM_ADV=TERM_100 [get_ports {pgpFabClkN}]

set_property PACKAGE_PIN AY17 [get_ports {pg_m2c[1]}]
set_property PACKAGE_PIN AY18 [get_ports {prsnt_m2c_l[1]}]


######################
# Timing Constraints #
######################

#create_clock -name pgpRefClk  -period  6.40 [get_ports pgpRefClkP]
create_clock -period 5.380 -name pgpRefClk [get_ports pgpRefClkP]

##############################################
# Crossing Domain Clocks: Timing Constraints #
##############################################

create_generated_clock -name pgpClk0 [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name pgpClk1 [get_pins {GEN_PGP[1].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name pgpClk2 [get_pins {GEN_PGP[2].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name pgpClk3 [get_pins {GEN_PGP[3].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks pgpRefClk] -group [get_clocks -include_generated_clocks pciRefClkP]


set_clock_groups -asynchronous \
                 -group [get_clocks [get_clocks -of_objects [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_186.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp186_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]]] \
                 -group [get_clocks [get_clocks -of_objects [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_186.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp186_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]]]

create_generated_clock -name dmaClk [get_pins xcvr_wrapper_inst0/RefClk_BUFG_Div2/O]
set_clock_groups -asynchronous \
		 -group [get_clocks dmaClk] \
		 -group [get_clocks pgpClk0] \
		 -group [get_clocks pgpClk1] \
		 -group [get_clocks pgpClk2] \
		 -group [get_clocks pgpClk3]

create_generated_clock -name phyClk0 [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name phyClk1 [get_pins {GEN_PGP[1].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name phyClk2 [get_pins {GEN_PGP[2].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
create_generated_clock -name phyClk3 [get_pins {GEN_PGP[3].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous -group [get_clocks pgpClk0] -group [get_clocks phyClk0]
set_clock_groups -asynchronous -group [get_clocks pgpClk1] -group [get_clocks phyClk1]
set_clock_groups -asynchronous -group [get_clocks pgpClk2] -group [get_clocks phyClk2]
set_clock_groups -asynchronous -group [get_clocks pgpClk3] -group [get_clocks phyClk3]

set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets fmc_debug_OBUF[0]]

