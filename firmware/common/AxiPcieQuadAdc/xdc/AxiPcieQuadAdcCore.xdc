
##############################
# StdLib: Custom Constraints #
##############################

set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]

###################
# I2C Constraints #
###################

set_property PACKAGE_PIN AV18 [get_ports scl]
set_property PACKAGE_PIN AW18 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

######################
# Timing Constraints #
######################

set_property PACKAGE_PIN AA37 [get_ports timingRefClkN]
set_property PACKAGE_PIN AA36 [get_ports timingRefClkP]

set_property PACKAGE_PIN N42 [get_ports timingRxN]
set_property PACKAGE_PIN N41 [get_ports timingRxP]
set_property PACKAGE_PIN M39 [get_ports timingTxN]
set_property PACKAGE_PIN M38 [get_ports timingTxP]

create_generated_clock -name pciClk [get_pins U_Core/U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/inst/AbacoPc821PciePhy_pcie3_ip_gt_top_i/phy_clk_i/bufg_gt_userclk/O]
create_generated_clock -name axilClk [get_pins U_Core/U_Clk/MmcmGen.U_Mmcm/CLKOUT0]
set_clock_groups -asynchronous \
		 -group [get_clocks pciClk] \
		 -group [get_clocks axilClk]
#set_clock_groups -asynchronous -group [get_clocks evrClk] -group [get_clocks timingFbClk]

#set_property LOC PCIE_3_1_X0Y0 [get_cells U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]
#set_property PACKAGE_PIN AP28 [get_ports pciRstL]
#set_property IOSTANDARD LVCMOS18 [get_ports pciRstL]
#set_property PULLUP true [get_ports pciRstL]
#set_false_path -from [get_ports pciRstL]

#create_pblock PCIE_PHY_GRP
#add_cells_to_pblock [get_pblocks PCIE_PHY_GRP] [get_cells -quiet [list U_Core/U_AxiPciePhy/U_AxiPcie]]
#resize_pblock [get_pblocks PCIE_PHY_GRP] -add {CLOCKREGION_X3Y0:CLOCKREGION_X3Y1}

#  Dissolve the timing constraint between adr_p and the MMCM outputs
#    The MMCM clkout1 is creating an impossible constraint on the channel a pins IDELAY to ISERDES
#set_false_path -to [get_pins {U_APP/U_FMC/ev10aq190_quad_phy_inst/serdes_mmcm_inst/MMCME3_ADV/CLKIN1}]





