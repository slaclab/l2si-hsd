# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load local Source Code and Constraints
loadSource -lib axi_pcie_core -path "$::DIR_PATH/rtl/AxiPciePkg.vhd"
loadSource -lib axi_pcie_core -path "$::DIR_PATH/rtl/AxiPcieRegPkg.vhd"
loadSource -path "$::DIR_PATH/rtl/AbacoPC820Core.vhd"
loadSource -path "$::DIR_PATH/rtl/AbacoPC820PciePhyWrapper.vhd"
loadSource -path "$::DIR_PATH/rtl/AxiPcieReg.vhd"

#loadIpCore -path "$::DIR_PATH/ip/AbacoPC820PciePhy.xci"
loadSource -path "$::DIR_PATH/ip/AbacoPC820PciePhy.dcp"

loadConstraints -path "$::DIR_PATH/ip/AbacoPC820PciePhy.xdc"
loadConstraints -dir  "$::DIR_PATH/xdc"
set_property PROCESSING_ORDER {EARLY}                      [get_files {AbacoPC820PciePhy.xdc}]
#set_property SCOPED_TO_REF    {AbacoPC820PciePhy_pcie3_ip} [get_files {AbacoPC820PciePhy.xdc}]
#set_property SCOPED_TO_CELLS  {inst}                       [get_files {AbacoPC820PciePhy.xdc}]


