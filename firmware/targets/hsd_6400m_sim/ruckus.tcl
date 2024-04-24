############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl "$::DIR_PATH/../../submodules"
loadRuckusTcl "$::DIR_PATH/../../common"
loadRuckusTcl "$::DIR_PATH/../../common/v3"
loadRuckusTcl "$::DIR_PATH/../../common/sim"
loadSource -path "$::DIR_PATH/../../common/PC821/Fmc134/rtl/FmcPkg/FmcPkg.vhd"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
