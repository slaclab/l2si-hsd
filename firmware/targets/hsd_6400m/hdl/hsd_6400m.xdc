set_property PACKAGE_PIN AT18 [get_ports timingModAbs]
set_property PACKAGE_PIN AT19 [get_ports timingRxLos]
set_property PACKAGE_PIN AT20 [get_ports timingTxDis]
set_property IOSTANDARD LVCMOS33 [get_ports timingModAbs]
set_property IOSTANDARD LVCMOS33 [get_ports timingRxLos]
set_property IOSTANDARD LVCMOS33 [get_ports timingTxDis]

#LCLSII (185.7 MHz)
create_clock -period 5.380 -name timingRefClkP [get_ports timingRefClkP]
#LCLS (238 MHz)
#create_clock -period 4.200 -name timingRefClkP [get_ports timingRefClkP]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks pciRefClkP] \
                 -group [get_clocks -include_generated_clocks timingRefClkP] \
                 -group [get_clocks -include_generated_clocks adc_refclka_0] \
                 -group [get_clocks -include_generated_clocks adc_refclka_1] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_0] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_1] \ 
                 -group [get_clocks -include_generated_clocks sysref_bufg] \
                 -group [get_clocks -include_generated_clocks lmk_devclk_bufg] \
                 -group [get_clocks -include_generated_clocks pgpRefClk]

#set_clock_groups -asynchronous \
#		 -group [get_clocks -of_objects [get_pins U_Core/U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O]] \
#		 -group [get_clocks -of_objects [get_pins U_Core/U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/inst/AbacoPc821PciePhy_pcie3_ip_gt_top_i/phy_clk_i/bufg_gt_userclk/O]]
		 
set_false_path -from [get_ports {pg_m2c[0]}]
set_false_path -from [get_ports {prsnt_m2c_l[0]}]

create_generated_clock -name dmaClk [get_pins xcvr_wrapper_inst0/RefClk_BUFG_Div2/O]
#create_generated_clock -name pciClk [get_pins U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_userclk/O]

create_generated_clock -name phyRxClk_7 [get_pins {GEN_PGP[7].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_7 [get_pins {GEN_PGP[7].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_7] \
                 -group [get_clocks pgpClk_7]

create_generated_clock -name phyRxClk_6 [get_pins {GEN_PGP[6].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_6 [get_pins {GEN_PGP[6].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_6] \
                 -group [get_clocks pgpClk_6]

create_generated_clock -name phyRxClk_5 [get_pins {GEN_PGP[5].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_5 [get_pins {GEN_PGP[5].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_5] \
                 -group [get_clocks pgpClk_5]

create_generated_clock -name phyRxClk_4 [get_pins {GEN_PGP[4].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_4 [get_pins {GEN_PGP[4].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_4] \
                 -group [get_clocks pgpClk_4]

create_generated_clock -name phyRxClk_3 [get_pins {GEN_PGP[3].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_3 [get_pins {GEN_PGP[3].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_3] \
                 -group [get_clocks pgpClk_3]

create_generated_clock -name phyRxClk_2 [get_pins {GEN_PGP[2].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_2 [get_pins {GEN_PGP[2].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_2] \
                 -group [get_clocks pgpClk_2]

create_generated_clock -name phyRxClk_1 [get_pins {GEN_PGP[1].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_1 [get_pins {GEN_PGP[1].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_1] \
                 -group [get_clocks pgpClk_1]

create_generated_clock -name phyRxClk_0 [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

create_generated_clock -name pgpClk_0 [get_pins {GEN_PGP[0].U_Pgp/U_Pgp3/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks dmaClk] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks phyRxClk_0] \
                 -group [get_clocks pgpClk_0]


#create_generated_clock -name pipeClk [get_pins U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_pclk/O]

set_clock_groups -asynchronous \
                 -group [get_clocks pciRefClkP] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks pipeClk]

create_generated_clock -name timingFbClk [get_pins {U_Core/U_TimingGth/GEN_EXTREF.U_TimingGthCore/inst/gen_gtwizard_gthe3_top.TimingGth_extref_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/TXOUTCLK}]

create_generated_clock -name evrClk [get_pins {U_Core/U_TimingGth/GEN_EXTREF.U_TimingGthCore/inst/gen_gtwizard_gthe3_top.TimingGth_extref_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/RXOUTCLK}]

set_clock_groups -asynchronous \
                 -group [get_clocks timingFbClk] \
                 -group [get_clocks evrClk]


set_false_path -from [get_pins {U_QuadCore/GEN_FMC[0].U_ChipAdcCore/dmaRstI_reg[2]/C}]
set_false_path -from [get_pins {U_QuadCore/GEN_FMC[1].U_ChipAdcCore/dmaRstI_reg[2]/C}]

