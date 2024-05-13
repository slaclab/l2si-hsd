
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





