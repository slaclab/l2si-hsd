##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
set format     "mcs"
set inteface   "bpix16"
set size       "128"

#  Option to load in upper boot memory (I think the address is 16-bit words)
#set size       "256"
#set loadbit "up 0x02000000 $::env(IMPL_DIR)/$::env(PROJECT).mcs"
#set outputFile    "$::env(IMPL_DIR)/$::env(PROJECT).mcs"
#set imagesFile    "$::env(IMAGES_DIR)/$::env(IMAGENAME).mcs"
