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

import lcls_hsd_tokenizer as lclsHsdtokenizer

class JesdAdc(pr.Device):
    def __init__( self,sim=False,**kwargs):
        super().__init__(**kwargs)

        self.add(lclsHsdtokenizer.fmc134_ctrl(
            offset = 0x0000_0000,
            # expand = True,
        ))
        for i in range(2):
                self.add(lclsHsdtokenizer.JesdRx(
                    name = f'JesdRx[{i}]',
                    offset = 0x0001_0000 + i*0x1_0000,
                ))
                
        self.add(lclsHsdtokenizer.pllreset(
            offset = 0x0003_0000,
            # expand = True,
        ))