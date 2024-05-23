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

class pllreset(pr.Device):
    def __init__( self,**kwargs):
        super().__init__(**kwargs)


        def addVar(name,offset,bitSize,bitOffset,mode):
            self.add(pr.RemoteVariable(
                name      = name,
                offset    = offset,
                bitSize   = bitSize,
                bitOffset = bitOffset,
                mode      = mode))


        addVar('prsnt_m2c_l_1'    ,0x00, 1, 0,'RO')
        addVar('pg_m2c_1'    ,0x00, 1, 1,'RO')

        addVar('oe_osc'    ,0x04, 1, 0,'RW')
        addVar('qpllrst'    ,0x04, 1, 4,'RW')

        addVar('monClkRate0'    ,0x08, 29, 0,'RO')  
        addVar('monClkSlow0'    ,0x08, 1, 29,'RO')  
        addVar('monClkFast0'    ,0x08, 1, 30,'RO')
        addVar('monClkLock0'    ,0x08, 1, 31,'RO')
   