#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'L2S-I HSD' project. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'L2S-I HSD', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr

import axipcie                                 as pcie
import l2si_hsd                                as hsd
#import lcls2_pgp_fw_lib.hardware.XilinxKcu1500 as xilinxKcu1500

class Hsd6400mSolo(pr.Device):
    def __init__(self,
                 numLanes = 2,
                 **kwargs):
        super().__init__(**kwargs)

        # Core Layer
        self.add(pcie.AxiPcieCore(
            offset      = 0x0000_0000,
            numDmaLanes = numLanes,
            expand      = False,
        ))

        # Application layer
        #   Add: I2C
#        self.add(hsd.Application(
#            offset   = 0x0010_0000,
#            numLanes = numLanes,
#            expand   = False,
#        ))
