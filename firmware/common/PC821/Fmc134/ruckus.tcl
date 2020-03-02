# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadIpCore -path "$::DIR_PATH/coregen/in_system_ibert_0.xci"
#loadIpCore -path "$::DIR_PATH/coregen/xcvr_fmc134.xci"
#No LOC constraints in this dcp
loadSource -path "$::DIR_PATH/coregen/xcvr_fmc134.dcp"
loadSource -dir "$::DIR_PATH/rtl/"
loadSource -path "$::DIR_PATH/rtl/FmcPkg/FmcPkg_Ilv.vhd"
loadConstraints -dir "$::DIR_PATH/xdc/"
