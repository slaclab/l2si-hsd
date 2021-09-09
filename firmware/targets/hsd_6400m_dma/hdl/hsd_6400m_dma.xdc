set_property PACKAGE_PIN AT18 [get_ports timingModAbs]
set_property PACKAGE_PIN AT19 [get_ports timingRxLos]
set_property PACKAGE_PIN AT20 [get_ports timingTxDis]
set_property IOSTANDARD LVCMOS33 [get_ports timingModAbs]
set_property IOSTANDARD LVCMOS33 [get_ports timingRxLos]
set_property IOSTANDARD LVCMOS33 [get_ports timingTxDis]

#LCLSII (185.7 MHz)
#create_clock -period 5.380 -name timingRefClkP [get_ports timingRefClkP]
#LCLS (119 MHz)
create_clock -period 8.400 -name timingRefClkP [get_ports timingRefClkP]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks pciRefClkP] \
                 -group [get_clocks -include_generated_clocks timingRefClkP] \
                 -group [get_clocks -include_generated_clocks adc_refclka_0] \
                 -group [get_clocks -include_generated_clocks adc_refclka_1] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_0] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_1] \ 
                 -group [get_clocks -include_generated_clocks sysref_bufg] \
                 -group [get_clocks -include_generated_clocks lmk_devclk_bufg]

create_generated_clock -name rxoutclk_6 [get_pins {U_Core/GEN_TIMING.U_TimingGth/GEN_EXTREF.U_TimingGthCore/inst/gen_gtwizard_gthe3_top.TimingGth_extref_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/RXOUTCLK}]

create_generated_clock -name txoutclk_4 [get_pins {U_Core/GEN_TIMING.U_TimingGth/GEN_EXTREF.U_TimingGthCore/inst/gen_gtwizard_gthe3_top.TimingGth_extref_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/TXOUTCLK}]

set_clock_groups -asynchronous \
		 -group [get_clocks rxoutclk_6] \
		 -group [get_clocks txoutclk_4]

set_false_path -from [get_ports {pg_m2c[0]}]
set_false_path -from [get_ports {prsnt_m2c_l[0]}]

set_false_path -from [get_pins {U_QuadCore/GEN_FMC[0].U_ChipAdcCore/dmaRstI_reg[2]/C}]
set_false_path -from [get_pins {U_QuadCore/GEN_FMC[1].U_ChipAdcCore/dmaRstI_reg[2]/C}]

######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
set_property BITSTREAM.CONFIG.BPI_PAGE_SIZE 8 [current_design]
set_property BITSTREAM.CONFIG.BPI_1ST_READ_CYCLE 3 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 3 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DIV-2 [current_design]

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CONFIG_MODE BPI16 [current_design]

##############################
# StdLib: Custom Constraints #
##############################

set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]

####################
# I2C Constraints #
####################

set_property PACKAGE_PIN AV18 [get_ports scl]
set_property PACKAGE_PIN AW18 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

####################
# PCIe Constraints #
####################

set_property PACKAGE_PIN BB3 [get_ports {pciRxN[7]}]
set_property PACKAGE_PIN BB4 [get_ports {pciRxP[7]}]
set_property PACKAGE_PIN BB7 [get_ports {pciTxN[7]}]
set_property PACKAGE_PIN BB8 [get_ports {pciTxP[7]}]

set_property PACKAGE_PIN BA1 [get_ports {pciRxN[6]}]
set_property PACKAGE_PIN BA2 [get_ports {pciRxP[6]}]
set_property PACKAGE_PIN BA5 [get_ports {pciTxN[6]}]
set_property PACKAGE_PIN BA6 [get_ports {pciTxP[6]}]

set_property PACKAGE_PIN AY3 [get_ports {pciRxN[5]}]
set_property PACKAGE_PIN AY4 [get_ports {pciRxP[5]}]
set_property PACKAGE_PIN AY7 [get_ports {pciTxN[5]}]
set_property PACKAGE_PIN AY8 [get_ports {pciTxP[5]}]

set_property PACKAGE_PIN AW1 [get_ports {pciRxN[4]}]
set_property PACKAGE_PIN AW2 [get_ports {pciRxP[4]}]
set_property PACKAGE_PIN AW5 [get_ports {pciTxN[4]}]
set_property PACKAGE_PIN AW6 [get_ports {pciTxP[4]}]

set_property PACKAGE_PIN AV3 [get_ports {pciRxN[3]}]
set_property PACKAGE_PIN AV4 [get_ports {pciRxP[3]}]
set_property PACKAGE_PIN AV7 [get_ports {pciTxN[3]}]
set_property PACKAGE_PIN AV8 [get_ports {pciTxP[3]}]

set_property PACKAGE_PIN AU1 [get_ports {pciRxN[2]}]
set_property PACKAGE_PIN AU2 [get_ports {pciRxP[2]}]
set_property PACKAGE_PIN AU5 [get_ports {pciTxN[2]}]
set_property PACKAGE_PIN AU6 [get_ports {pciTxP[2]}]

set_property PACKAGE_PIN AT3 [get_ports {pciRxN[1]}]
set_property PACKAGE_PIN AT4 [get_ports {pciRxP[1]}]
set_property PACKAGE_PIN AT7 [get_ports {pciTxN[1]}]
set_property PACKAGE_PIN AT8 [get_ports {pciTxP[1]}]

set_property PACKAGE_PIN AR1 [get_ports {pciRxN[0]}]
set_property PACKAGE_PIN AR2 [get_ports {pciRxP[0]}]
set_property PACKAGE_PIN AR5 [get_ports {pciTxN[0]}]
set_property PACKAGE_PIN AR6 [get_ports {pciTxP[0]}]

set_property PACKAGE_PIN AR9 [get_ports pciRefClkN]
set_property PACKAGE_PIN AR10 [get_ports pciRefClkP]

####################
# Timing Constraints #
####################

create_clock -period 10.000 -name pciRefClkP [get_ports pciRefClkP]

create_generated_clock -name dmaClk [get_pins xcvr_wrapper_inst0/RefClk_BUFG_Div2/O]
create_generated_clock -name pciClk [get_pins U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_userclk/O]
create_generated_clock -name pipeClk [get_pins U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_pclk/O]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/gt_wizard.gtwizard_top_i/AbacoPC820PciePhy_pcie3_ip_gt_i/inst/gen_gtwizard_gthe3_top.AbacoPC820PciePhy_pcie3_ip_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[25].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST/TXOUTCLK}]] -group [get_clocks pciRefClkP]

#  Correct the clock rates (320MHz)
create_clock -period 3.125 -name adc_refclka_0 [get_ports {adc_refclka_p[0]}]
create_clock -period 3.125 -name adc_refclkb_0 [get_ports {adc_refclkb_p[0]}]
create_clock -period 3.125 -name adc_refclka_1 [get_ports {adc_refclka_p[1]}]
create_clock -period 3.125 -name adc_refclkb_1 [get_ports {adc_refclkb_p[1]}]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks pciRefClkP] \
                 -group [get_clocks -include_generated_clocks adc_refclka_0] \
                 -group [get_clocks -include_generated_clocks adc_refclka_1] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_0] \
                 -group [get_clocks -include_generated_clocks adc_refclkb_1] \ 
                 -group [get_clocks -include_generated_clocks sysref_bufg] \
                 -group [get_clocks -include_generated_clocks lmk_devclk_bufg]

set_clock_groups -asynchronous \
                 -group [get_clocks pciRefClkP] \
                 -group [get_clocks pciClk] \
                 -group [get_clocks pipeClk]

create_generated_clock -name dnaClk [get_pins U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O]
create_generated_clock -name flashClk [get_pins U_Core/U_Clk/MmcmGen.U_Mmcm/CLKOUT0]

set_clock_groups -asynchronous -group [get_clocks dnaClk] -group [get_clocks pciClk]
set_clock_groups -asynchronous -group [get_clocks flashClk] -group [get_clocks pciClk]

set_property LOC PCIE_3_1_X0Y0 [get_cells U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]
set_property PACKAGE_PIN AP28 [get_ports pciRstL]
set_property IOSTANDARD LVCMOS18 [get_ports pciRstL]
set_property PULLUP true [get_ports pciRstL]
set_false_path -from [get_ports pciRstL]

create_pblock PCIE_PHY_GRP
add_cells_to_pblock [get_pblocks PCIE_PHY_GRP] [get_cells -quiet [list U_Core/U_AxiPciePhy/U_AxiPcie]]
resize_pblock [get_pblocks PCIE_PHY_GRP] -add {CLOCKREGION_X3Y0:CLOCKREGION_X3Y1}






