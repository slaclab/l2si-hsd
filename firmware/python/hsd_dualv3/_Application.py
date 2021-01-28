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
import time

import surf.protocols.batcher as batcher
import l2si_core              as l2si_core

class PhaseDetector(pr.Device):
    def __init__(   self,
            name        = "PhaseDetector",
            description = "Measures the ADC-Timing clock phases",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = 'Value[%d]'%i,
                offset       = 0x20+4*i,
                bitSize      = 16,
                mode         = 'RO',
            ))
            self.add(pr.RemoteVariable(
                name         = 'Count[%d]'%i,
                offset       = 0x30+4*i,
                bitSize      = 16,
                mode         = 'RO',
            ))

class StreamBase(pr.Device):
    def __init__(   self,
                    name        = "StreamBase",
                    description = "stream base config",
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addVar(name,offset,bitSize,bitOffset,mode):
            self.add(pr.RemoteVariable(
                name      = name,
                offset    = offset,
                bitSize   = bitSize,
                bitOffset = bitOffset,
                mode      = mode,
                verify    = False))

        addVar('prescale'   ,0x00,10, 0,'RW')
        addVar('beginRow'   ,0x04,10, 0,'RW')
        addVar('gateRow'    ,0x04,10,16,'RW')
        addVar('aFullRows'  ,0x08,16, 0,'RW')
        addVar('aFullEvents',0x08, 5,16,'RW')
        addVar('freeRows'   ,0x0C,16, 0,'RO')
        addVar('freeEvents' ,0x0C, 5,16,'RO')
        addVar('countOflow' ,0x0C, 8,24,'RO')

class StreamApp(pr.Device):
    def __init__(   self,
                    name        = "StreamApp",
                    description = "stream app config",
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        for i in range(30):
            self.add(pr.RemoteVariable(
                name    = 'parm[%d]'%i,
                offset  = 0x10+i*4,
                bitSize = 32))


class FexCfg(pr.Device):
    def __init__(   self,
                    name        = "FexCfg",
                    description = "Feature extraction config",
                    nstreams    = 5,
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addVar(name, offset, bitSize, bitOffset, mode):
            self.add(pr.RemoteVariable(
                name    = name,
                offset  = offset,
                bitSize = bitSize,
                bitOffset = bitOffset,
                mode      = mode,
                verify    = False))

        addVar('enabledStreams',0x00,nstreams,0,'RW')
        addVar('almostFullN'   ,0x00,5,8,'RW')
        addVar('cntOflow'      ,0x04,8,0,'RO')
        addVar('eventStreams'  ,0x08,nstreams,0,'RO')
        addVar('currentStream' ,0x08,3,5,'RO')
        addVar('streamValids'  ,0x08,nstreams,8,'RO')
        addVar('slaveReady'    ,0x08,1,13,'RO')
        addVar('masterValid'   ,0x08,1,14,'RO')
        addVar('slaveReady2'   ,0x08,1,15,'RO')
        addVar('addrRd'        ,0x08,16,16,'RO')
        addVar('npend'         ,0x0C,5,0,'RO')
        addVar('ntrig'         ,0x0C,5,5,'RO')
        addVar('nread'         ,0x0C,5,10,'RO')
        addVar('addrWr'        ,0x0C,16,16,'RO')

        for i in range(nstreams):
            self.add(StreamBase(
                name = 'StreamBase[%d]'%i,
                offset = 0x10 + 0x10*i))
            if i<4:
                addVar('streamChan[%d]'%i, 0x100+i*0x100, 2, 0, 'RW')

class FmcCore(pr.Device):
    def __init__(   self,
            name        = "FmcCore",
            description = "Mezzanine Core",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addVar(name,offset,mode='RO'):
            self.add(pr.RemoteVariable(
                name         = name,
                offset       = offset,
                bitSize      = 32,
                mode         = mode
            ))

        addVar('irq'   ,0x00)
        addVar('irqEn' ,0x04)
        addVar('detect',0x20)
        addVar('cmd'   ,0x24)
        addVar('ctrl'  ,0x28)
        addVar('clkcnt',0x44)

        self.add(pr.RemoteVariable(
            name      = 'clksel',
            offset    = 0x40,
            bitSize   = 32,
            mode      = 'RW',
            enum      = {0:'AxiLite',1:'PhyA',2:'PhyB',3:'PhyC',4:'phyD',5:'RefClk',6:'AdcClk'}))

        def getClockRate(var):
            x = var.dependencies[0].value()
            return x/8192.*125.

        self.add(pr.LinkVariable(
            name  = 'clockRate',
            mode  = 'RO',
            units = 'MHz',
            linkedGet = getClockRate,
            disp      = '{:3.2f}',
            dependencies = [self.clkcnt]))

class AdcCore(pr.Device):
    def __init__(   self,
                    name        = 'AdcCore',
                    description = 'Adc core',
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addVar(name,offset,mode='RO',bitSize=32,bitOffset=0):
            self.add(pr.RemoteVariable(
                name         = name,
                offset       = offset,
                bitSize      = bitSize,
                bitOffset    = bitOffset,
                mode         = mode,
                verify       = False
            ))

        addVar('cmd'           ,0  , 'RW')
        addVar('status'        ,0x4)
        addVar('master_start'  ,0x8, 'RW')
        addVar('adrclk_delay'  ,0xc, 'RW')
        addVar('channel_select',0x10,'RW')
        addVar('tap_match_lo'  ,0x14)
        addVar('tap_match_hi'  ,0x18)
        addVar('adc_req_tap'   ,0x1c)

        @self.command()
        def train(arg):
            # init_training
            self.cmd.set(3)
            time.sleep(0.05)
            self.adrclk_delay.set(arg)
            self.master_start.set(0x140)

            # start_training
            time.sleep(0.5)
            self.cmd.set(4)
            time.sleep(0.05)
            
            self.cmd.set(8)
            time.sleep(0.05)

            while True:
                v = self.status.get()
                if (v&0x3f)==0x36:
                    print('FMC Ready')
                    break
                else:
                    print('FMC Busy')
                    time.sleep(0.1)

            # dump_training
            print('\tFMC')
            for i in range(44):
                self.channel_select.set(i)
                csel = self.channel_select.get()
                mhi  = self.tap_match_hi.get()
                mlo  = self.tap_match_lo.get()
                tap  = self.adc_req_tap.get()
                print('[Ch{:}:b{:} 0x{:08x}{:08x} : {:} ({:f} ps)'
                      .format('ABCD'[int(csel/11)],csel%11,mhi,mlo,tap,tap*1250./512.))
 
        @self.command()
        def loop_checking():
            CheckTime = 10;
            ch_fails = [0]*4

            for i in range(CheckTime):
                # Reset pattern error flag
                v = self.status.get()
                # Test for one second
                time.sleep(0.1)
                # Read pattern error flags
                v = self.status.get()
                if (v&0x1000):
                    ch_fails[0] += 1
                if (v&0x2000):
                    ch_fails[1] += 1
                if (v&0x4000):
                    ch_fails[2] += 1
                if (v&0x8000):
                    ch_fails[3] += 1
                # Report
                line = 'Pattern check   : {:} seconds '.format((i+1)*0.1)
                for j in range(4):
                    line += f'| ADC{j}: {ch_fails[j]}'
                print(line)


class DSReg(pr.Device):
    def __init__(   self,
                    name        = "DSReg",
                    description = "Core",
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addVar(name,offset,mode='RO',bitSize=32,bitOffset=0):
            self.add(pr.RemoteVariable(
                name         = name,
                offset       = offset,
                bitSize      = bitSize,
                bitOffset    = bitOffset,
                mode         = mode
            ))

        def addCmd(name,offset,bitOffset=0):
            self.add(pr.RemoteCommand(
                name         = name,
                offset       = offset,
                bitSize      = 1,
                bitOffset    = bitOffset,
                function     = pr.RemoteCommand.toggle
            ))

        addVar('irqEnable'   ,0x00, 'RW')
        addVar('irqStatus'   ,0x04)
        addVar('countRst'    ,0x10, 'RW', 1, 0)
        addVar('dmaTest'     ,0x10, 'RW', 1, 2)
        addVar('adcSyncRst'  ,0x10, 'RW', 1, 3 )
        addCmd('resetDma'    ,0x10, 4)
        addCmd('resetFb'     ,0x10, 5)
        addCmd('resetFbPLL'  ,0x10, 6)
        addVar('trigShift'   ,0x10, 'RW', 3, 8 )
        addCmd('fmc0Rst'     ,0x10, 28 )
        addCmd('fmc1Rst'     ,0x10, 29 )
        addVar('acqEnable'   ,0x10, 'RW', 1, 30 )
        #addVar('rateDestSel' ,0x14, 'RW')
        #addVar('enable'      ,0x18, 'RW', 1, 0)
        #addVar('intlv'       ,0x18, 'RW', 1, 8)
        addVar('inhibit'     ,0x18, 'RW', 1, 24)
        addVar('samples'     ,0x1C, 'RW')
        #addVar('prescale'    ,0x20, 'RW')
        #addVar('offset'      ,0x24, 'RW')

        addVar('trigcnt'     ,0x28 )
        addVar('timframecnt' ,0x2C )
        addVar('timpausecnt' ,0x30 )
        addVar('readcnt'     ,0x34 )

        addVar('cacheSel'    ,0x40, 'RW' )
        self.add(pr.RemoteVariable(
            name      = 'cacheState',
            offset    = 0x44,
            bitSize   = 4,
            bitOffset = 0,
            enum      = {0:'Empty',1:'Open',2:'Closed',3:'Reading',4:'Last'},
            mode      = 'RO'))
        self.add(pr.RemoteVariable(
            name      = 'cacheTrigd',
            offset    = 0x44,
            bitSize   = 4,
            bitOffset = 4,
            enum      = {0:'Wait',1:'Accept',2:'Reject'},
            mode      = 'RO'))
        addVar('cacheSkip', 0x44, 'RO', 1, 8)
        addVar('cacheOF'  , 0x44, 'RO', 1, 9)
        addVar('cacheBeg' , 0x48, 'RO', 16, 0)
        addVar('cacheEnd' , 0x48, 'RO', 16, 16)

        addVar('localId'  , 0x68, 'RW')

class Application(pr.Device):
    def __init__(   self,
            name        = "Application",
            description = "PCIe Lane Container",
            numLanes    = 4, # number of PGP Lanes
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(DSReg(
            name   = 'Base',
            offset = 0,
            expand = False ))

        #self.add(Mmcm(
        #    name   = 'MmcmPhaseShift',
        #    offset = 0x0000_0800,
        #    expand = False ))

        # AdcSyncCal @0000_2000

        self.add(PhaseDetector(
            offset = 0x0000_2800,
            expand = False ))

        self.add(l2si_core.TriggerEventManager(
            name   = 'TriggerEventManager',
            offset = 0x0001_0000,
            enLclsI=True,
            enLclsII=False,
            expand = False ))

        for i in range(numLanes):

            self.add(FmcCore(
                name   = ('FmcCore[%i]' % i),
                offset = (0x0000_1000 + i*0x800),
                expand = False ))

            self.add(AdcCore(
                name   = ('AdcCore[%i]' % i),
                offset = (0x0000_1400 + i*0x800),
                expand = False ))

            self.add(FexCfg(
                name   = 'FexCfg[%i]'%i,
                offset = (0x0000_8000 + i*0x1000),
                expand = False ))

