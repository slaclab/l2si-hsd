export GIT_BYPASS = 1

export REMOVE_UNUSED_CODE = 1

# Define target output
target: prom

# Define Firmware Version Number
#  PRJ_VERSION 00000000 : LCLS-I implementation
#  PRJ_VERSION 00000001 : Add streams for individual channels
export PRJ_VERSION = 000000001

# Define target part
export PRJ_PART = XCKU085-FLVB1760-2-E
export BOARD_PART = 
export PRJ_FMC = 126

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
