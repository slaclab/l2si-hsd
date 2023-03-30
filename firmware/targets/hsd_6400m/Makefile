export GIT_BYPASS = 1
export REMOVE_UNUSED_CODE = 1
export TIMING_EXT_PKG = 1

# Define target output
target: prom

# Define Firmware Version Number
#
# PRJ_VERSION = 00000000  First version with readout, but bad JESD link 
# PRJ_VERSION = 00000001  JESD link fixed, two PGP links driven by timing reference clock
# PRJ_VERSION = 00000002  Put back seemingly unnecessary skip characters.  Increase skip range to 15b.
# PRJ_VERSION = 00000003  Remove some unused config parameters.  Add ILA.
# PRJ_VERSION = 00000004  Refactor register space
# PRJ_VERSION = 00000005  Build with surf fork.  Remove DMA infrastructure altogether.
# PRJ_VERSION = 00000006  Add fine grain sparsification.
# PRJ_VERSION = 00000007  Fix errors when no payload or no unprescaled streams
# PRJ_VERSION = 00000008  Explore flash controller errors
# PRJ_VERSION = 00000009  Use common TriggerEventManager
# PRJ_VERSION = 0000000A  Simplify trigger/shift logic
# PRJ_VERSION = 0000000B  Synchr l0,l1 bits+tag in CDC.  Validate tag.
# PRJ_VERSION = 0000000C  Add l2si-core trigfifo-fix
# PRJ_VERSION = 0000000D  Remove data dump preventing long gate delays or widths
# PRJ_VERSION = 0000000E  Add disableFull register to allow loopback mode running
#

export PRJ_VERSION = 0000000E

# Define target part
export PRJ_PART = XCKU085-FLVB1760-2-E
export BOARD_PART = 
export PRJ_FMC = 134

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
