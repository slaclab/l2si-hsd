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
loadRuckusTcl "$::DIR_PATH/../../common/pgp"
loadRuckusTcl "$::DIR_PATH/../../common/AxiPcieQuadAdc"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/../../common/core/xdc/"
loadConstraints -dir  "$::DIR_PATH/../../common/AxiPcieQuadAdc/xdc/"
