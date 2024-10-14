#-----------------------------------------------------------------------------
# This file is part of the 'snl-trans-fes'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'snl-trans-fes', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import surf.protocols.jesd204b

class JesdRx(surf.protocols.jesd204b.JesdRx):
    def __init__(               self,
            numRxLanes  =  2,
            instantiate =  True,
            debug       =  False,
            **kwargs):

        # Pass custom value to parent via super function
        super().__init__(numRxLanes  =  numRxLanes, instantiate =instantiate,debug = debug, **kwargs)

        if (debug):
            self.addRemoteVariables(
                name         = "s_statusRxArr",
                description  = "statusRxArr",
                offset       =  0x180,
                bitSize      =  16,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
            )
