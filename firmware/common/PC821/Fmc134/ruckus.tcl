# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadIpCore -dir "$::DIR_PATH/coregen/"
loadSource -dir "$::DIR_PATH/rtl/"
loadSource -path "$::DIR_PATH/rtl/FmcPkg/FmcPkg_Ilv.vhd"
loadConstraints -dir "$::DIR_PATH/xdc/"
