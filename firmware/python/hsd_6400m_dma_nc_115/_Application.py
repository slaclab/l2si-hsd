
# -------------------------------------------------------------------------------
# -- Company    : SLAC National Accelerator Laboratory
# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------
# -- This file is part of 'lcls-hsd-tokenizer'.
# -- It is subject to the license terms in the LICENSE.txt file found in the
# -- top-level directory of this distribution and at:
# --    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# -- No part of 'lcls-hsd-tokenizer', including this file,
# -- may be copied, modified, propagated, or distributed except according to
# -- the terms contained in the LICENSE.txt file.
# -------------------------------------------------------------------------------

import pyrogue as pr
import surf.axi as axi

import hsd_6400m_dma_nc_115 as  hsd_6400m       # Add the JesdAdc device to base


class Application(pr.Device):
    def __init__( self,sim=False,**kwargs):
        super().__init__(**kwargs)

        # Add the JesdAdc device to base
        self.add(hsd_6400m.JesdAdc(
            offset      = 0x0000_0000,
            # memBase     = self.memMap,
            # sim         = self.sim,
            expand      = True,
        ))

