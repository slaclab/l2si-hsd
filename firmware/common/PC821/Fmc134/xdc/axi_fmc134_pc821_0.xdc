################################################################################
# FMC signals FMC134 on PC821
################################################################################
set_property PACKAGE_PIN N29 [get_ports {lmk_out_n[2]}]
set_property PACKAGE_PIN N28 [get_ports {lmk_out_p[2]}]
set_property PACKAGE_PIN M31 [get_ports {lmk_out_n[3]}]
set_property PACKAGE_PIN N31 [get_ports {lmk_out_p[3]}]
set_property IOSTANDARD LVDS [get_ports {lmk_out_p[*]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {lmk_out_n[*]}]

set_property PACKAGE_PIN   M30      [get_ports buf_ext_trig_to_fpga_p_0]
set_property PACKAGE_PIN   L30      [get_ports buf_ext_trig_to_fpga_n_0]
set_property IOSTANDARD    LVDS     [get_ports buf_ext_trig_to_fpga_*_0]
set_property DIFF_TERM_ADV TERM_100 [get_ports buf_ext_trig_to_fpga_*_0]

set_property PACKAGE_PIN   N32      [get_ports fpga_sync_out_p]
set_property PACKAGE_PIN   M32      [get_ports fpga_sync_out_n]
set_property IOSTANDARD    LVDS     [get_ports fpga_sync_out_*]

set_property PACKAGE_PIN M29 [get_ports {adc_ora[0][0]}]
set_property PACKAGE_PIN L29 [get_ports {adc_ora[0][1]}]
set_property PACKAGE_PIN R30 [get_ports {adc_orb[0][0]}]
set_property PACKAGE_PIN P30 [get_ports {adc_orb[0][1]}]
set_property PACKAGE_PIN K30 [get_ports {adc_ora[1][0]}]
set_property PACKAGE_PIN K31 [get_ports {adc_ora[1][1]}]
set_property PACKAGE_PIN L28 [get_ports {adc_orb[1][0]}]
set_property PACKAGE_PIN K28 [get_ports {adc_orb[1][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_or*[*][*]}]

set_property PACKAGE_PIN U29 [get_ports {adc_ncoa[0][0]}]
set_property PACKAGE_PIN T29 [get_ports {adc_ncoa[0][1]}]
set_property PACKAGE_PIN U30 [get_ports {adc_ncob[0][0]}]
set_property PACKAGE_PIN T30 [get_ports {adc_ncob[0][1]}]
set_property PACKAGE_PIN N26 [get_ports {adc_ncoa[1][0]}]
set_property PACKAGE_PIN N27 [get_ports {adc_ncoa[1][1]}]
set_property PACKAGE_PIN W28 [get_ports {adc_ncob[1][0]}]
set_property PACKAGE_PIN Y28 [get_ports {adc_ncob[1][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_nco*[*][*]}]

set_property PACKAGE_PIN T28 [get_ports {adc_syncse_n[0]}]
set_property PACKAGE_PIN R28 [get_ports {adc_syncse_n[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_syncse_n[*]}]

set_property PACKAGE_PIN Y32 [get_ports {adc_calstat[0]}]
set_property PACKAGE_PIN Y33 [get_ports {adc_calstat[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_calstat[*]}]

set_property PACKAGE_PIN AA34 [get_ports sync_to_lmk]
set_property IOSTANDARD LVCMOS18 [get_ports sync_to_lmk]

set_property PACKAGE_PIN   AB34     [get_ports firefly_int_0]
set_property IOSTANDARD    LVCMOS18 [get_ports firefly_int_0]

set_property PACKAGE_PIN BB16 [get_ports {prsnt_m2c_l[0]}]
set_property PACKAGE_PIN AY16 [get_ports {pg_m2c[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports p*_m2c*]

# MGT RefClk Signals
set_property PACKAGE_PIN P7 [get_ports {adc_refclka_n[0]}]
set_property PACKAGE_PIN P8 [get_ports {adc_refclka_p[0]}]
set_property PACKAGE_PIN V7 [get_ports {adc_refclkb_n[0]}]
set_property PACKAGE_PIN V8 [get_ports {adc_refclkb_p[0]}]
set_property PACKAGE_PIN AK7 [get_ports {adc_refclka_n[1]}]
set_property PACKAGE_PIN AK8 [get_ports {adc_refclka_p[1]}]
set_property PACKAGE_PIN AF7 [get_ports {adc_refclkb_n[1]}]
set_property PACKAGE_PIN AF8 [get_ports {adc_refclkb_p[1]}]

#set_property PACKAGE_PIN AR13 [get_ports pllRefClk]
#  RefClk routed through FMC #H23 to FMC134 #CI
#set_property PACKAGE_PIN AE28 [get_ports pllRefClk]
#  Fmc134 pins are in stacked configuration
#  H23(LA19_N) on stacked connector maps to F5(HA00_N) on carrier connector
#  which maps to AL24 on FPGA
set_property PACKAGE_PIN AL24 [get_ports pllRefClk]
set_property IOSTANDARD LVCMOS18 [get_ports pllRefClk]
set_property DRIVE 12 [get_ports pllRefClk]
#set_property SLEW SLOW [get_ports pllRefClk]

set_property PACKAGE_PIN AR12 [get_ports {fmc_debug[0]}]
set_property PACKAGE_PIN AL10 [get_ports {fmc_debug[1]}]
set_property PACKAGE_PIN AM10 [get_ports {fmc_debug[2]}]
set_property PACKAGE_PIN AP18 [get_ports {fmc_debug[3]}]
set_property PACKAGE_PIN AR18 [get_ports {fmc_debug[4]}]
set_property PACKAGE_PIN AL15 [get_ports {fmc_debug[5]}]
set_property PACKAGE_PIN AL14 [get_ports {fmc_debug[6]}]
set_property PACKAGE_PIN AM11 [get_ports {fmc_debug[7]}]

###############################################################################
# Timing Constraints
###############################################################################

create_clock -period 3.125 -name adc_refclka_0 [get_ports {adc_refclka_p[0]}]
create_clock -period 3.125 -name adc_refclkb_0 [get_ports {adc_refclkb_p[0]}]
create_clock -period 3.125 -name adc_refclka_1 [get_ports {adc_refclka_p[1]}]
create_clock -period 3.125 -name adc_refclkb_1 [get_ports {adc_refclkb_p[1]}]

create_clock -period 100.000 -name sysref_bufg [get_ports {lmk_out_p[3]}]
create_clock -period 5.380 -name lmk_devclk_bufg [get_ports {lmk_out_p[2]}]
create_clock -period 20.00 -name ext_trigger     [get_pins axi_fmc134_0/fmc134_inst/ext_trigger_inst/i_ext_trigger_bufg/O]; # 50 MHz

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks sysref_bufg] -group [get_clocks -include_generated_clocks adc_refclka_0]


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets axi_fmc134_0/fmc134_inst/ext_trigger_inst/ibufds_trig/O]

###############################################################################
# End FMC134 on PC821 constraints section
###############################################################################


