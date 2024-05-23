#-----------------------------------------------------------------------------
# This file is part of the 'lcls_tokenizer'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'atlas-4d-tracking-dev', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class DebugClk(pr.Device):
    def __init__( self,**kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'otherClkFreq',
            description  = 'FMC PllClk Frequency',
            offset       = 0x00,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'Hz',
            pollInterval = 1,
            number       = 2,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name         = 'dataClkFreq',
            description  = 'dataClk Frequency',
            offset       = 0x14,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'Hz',
            pollInterval = 1,
        ))



