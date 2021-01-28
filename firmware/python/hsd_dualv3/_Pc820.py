#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'Camera link gateway'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'Camera link gateway', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr

import axipcie                                 as pcie
import hsd_dualv3                              as dev
import LclsTimingCore

class Pc820(pr.Device):
    def __init__(self,
                 numLanes = 2,
                 enLclsI  = True,
                 enLclsII = False,
                 **kwargs):
        super().__init__(**kwargs)

        # Core Layer
        self.add(pcie.AxiPcieCore(
            offset      = 0x0000_0000,
            numDmaLanes = numLanes,
            expand      = False,
        ))

        # Flash @0x0008_0000
        # XVC   @0x0009_0000

        # I2C   @0x000A_0000
        self.add(dev.I2c126(
            name   = 'I2cBus',
            offset = 0x000A_0000,
            expand = False))

        # GTH   @0x000B_0000
        self.add(LclsTimingCore.GthRxAlignCheck(
            name   = "GthRxAlignCheck",
            offset = 0x000B_0000,
            expand = False,
            hidden = True ))

        # TIM   @0x000C_0000
        self.add(LclsTimingCore.TimingFrameRx(
            offset = 0x000C_0000,
            expand = False ))

        # Application layer
        self.add(dev.Application(
            offset   = 0x0010_0000,
            numLanes = numLanes,
            expand   = False,
        ))
