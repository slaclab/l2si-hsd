# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(PRJ_FMC) == "134" } {
    loadRuckusTcl "$::DIR_PATH/Fmc134"
} else {
    loadRuckusTcl "$::DIR_PATH/Fmc126"
}

loadSource -dir "$::DIR_PATH/cid/rtl/"
loadSource -dir "$::DIR_PATH/host/flash_controller/"
