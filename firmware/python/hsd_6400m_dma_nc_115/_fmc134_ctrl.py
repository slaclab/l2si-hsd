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

class fmc134_ctrl(pr.Device):
    def __init__( self,**kwargs):
        super().__init__(**kwargs)


        def addVar(name,offset,bitSize,bitOffset,mode):
            self.add(pr.RemoteVariable(
                name      = name,
                offset    = offset,
                bitSize   = bitSize,
                bitOffset = bitOffset,
                mode      = mode))


        addVar('prsnt_m2c_l'    ,0x00, 1, 0,'RO')
        addVar('pg_m2c'    ,0x00, 1, 1,'RO')

        addVar('xcvr_rxrst'    ,0x04, 1, 0,'RW')
        addVar('sysref_sync_en'    ,0x04, 1, 1,'RW')
        addVar('align_enable'    ,0x04, 1, 4,'RW')  
        addVar('rxdfeagchold'    ,0x04, 1, 8,'RW')
        addVar('rxdfelfhold'    ,0x04, 1, 9,'RW')
        addVar('rxdfetaphold'    ,0x04, 1, 10,'RW')
        addVar('rxlpmgchold'    ,0x04, 1, 11,'RW')
        addVar('rxlpmhfhold'    ,0x04, 1, 12,'RW')
        addVar('rxlpmlfhold'    ,0x04, 1, 13,'RW')
        addVar('rxlpmoshold'    ,0x04, 1, 14,'RW')
        addVar('rxoshold'    ,0x04, 1, 15,'RW')
        addVar('rxcdrhold'    ,0x04, 1, 16,'RW')
        addVar('rxdfetapovrden'    ,0x04, 1, 17,'RW')

        addVar('status'    ,0x08, 32, 0,'RO')
        addVar('adc_valid'    ,0x0C, 4, 0,'RO')

        addVar('scrambling_en'    ,0x10, 1, 0,'RW')

        addVar('sw_trigger'    ,0x14, 1, 0,'RW')
        addVar('sw_trigger_en'    ,0x14, 1, 4,'RW')
        addVar('hw_trigger_en'    ,0x14, 1, 8,'RW')

        addVar('k_lmfc_cnt'    ,0x18, 5, 0,'RW')

        addVar('f_align_char'    ,0x1C, 8, 0,'RW')

        addVar('fpga_sync'    ,0x20, 1, 0,'RW')
        addVar('adc_ncoa0'    ,0x20, 2, 8,'RW')
        addVar('adc_ncob0'    ,0x20, 2, 10,'RW')
        addVar('adc_ncoa1'    ,0x20, 2, 12,'RW')
        addVar('adc_ncob1'    ,0x20, 2, 14,'RW')

        addVar('adc_ora0'    ,0x24, 2, 0,'RO')
        addVar('adc_orb0'    ,0x24, 2, 2,'RO')
        addVar('adc_ora1'    ,0x24, 2, 4,'RO')
        addVar('adc_orb1'    ,0x24, 2, 6,'RO')
        addVar('adc_calstat'    ,0x24, 2, 16,'RO')
        addVar('firefly_int'    ,0x24, 1, 18,'RO')

        addVar('test_clksel'    ,0x28, 4, 0,'RW')
        # addVar('rxdfetapovrden'    ,0x2C, 16, 0,'RO')

