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

import lcls_hsd_tokenizer as lclsHsdtokenizer 
import surf.axi as axi

class Application(pr.Device):
    def __init__( self,sim=False,**kwargs):
        super().__init__(**kwargs)

        self.add(axi.AxiStreamRingBuffer(
            offset   = 0x00_000000,
            # expand   = True,
        ))
        self.add(lclsHsdtokenizer.I2c134(
            name   = 'I2cBus',
            offset = 0x0001_0000,
            expand = False))
        self.add(lclsHsdtokenizer.DebugClk(
            name   = 'DebugClk',
            offset = 0x0002_0000,
            expand = False))
        # self.add(lclsHsdtokenizer.AppTx(
        #     offset = 0x0000_0000,
        #     expand = True,
        # ))
        # self.add(devBoard.WeinerFilter(
        #     offset = 0x0010_1000,
        #     # expand = True,
        # ))
