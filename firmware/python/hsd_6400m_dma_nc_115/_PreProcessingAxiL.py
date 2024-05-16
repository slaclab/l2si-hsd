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

class PreProcessingAxiL(pr.Device):
    def __init__( self,**kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'BitMaskThreshold',
            description  = 'Threshold for the comparator used after the IFFT',
            offset       = 0x000,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.Float,
            mode         = 'RW',
            number       = 48, # 48 Channels
            stride       = 4,  # 4 bytes = 32-bit stride between variables
        )

        self.add(pr.RemoteVariable(
            name         = 'AppReset',
            description  = 'Used to reset the application modules and clear out the data pipeline',
            offset       = 0xFFC,
            bitSize      = 1,
            mode         = 'RW',
        ))
