############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
#source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
source $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl "$::DIR_PATH/../../submodules"
loadRuckusTcl "$::DIR_PATH/../../common"
loadRuckusTcl "$::DIR_PATH/../../common/v3"
loadRuckusTcl "$::DIR_PATH/../../common/jesd204b"

loadRuckusTcl "$::DIR_PATH/../../common/PC820"
loadRuckusTcl "$::DIR_PATH/../../submodules/axi-pcie-core/shared"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/../../common/core/xdc/"
