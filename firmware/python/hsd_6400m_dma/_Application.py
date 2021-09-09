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

class ChipAdcReg(pr.Device):
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

        def addEnum(name,offset,bitSize,bitOffset,mode,enum):
            self.add(pr.RemoteVariable(
                name      = name,
                offset    = offset,
                bitSize   = bitSize,
                bitOffset = bitOffset,
                mode      = mode,
                enum      = enum,
                verify    = False))

        def addCmd(name,offset,bitOffset=0):
            self.add(pr.RemoteCommand(
                name         = name,
                offset       = offset,
                bitSize      = 1,
                bitOffset    = bitOffset,
                function     = pr.RemoteCommand.toggle
            ))

#        addCmd('countReset'   ,0x10, 0)
        addCmd('countRst'     ,0x10, 0)
        addCmd('adcSyncReset' ,0x10, 3)
        addCmd('dmaReset'     ,0x10, 4)
        addCmd('fbReset'      ,0x10, 5)
        addCmd('fbPLLReset'   ,0x10, 6)
        addVar('acqEnable'    ,0x10, 1,31,'RW')

        addVar('dmaRstIn'     ,0x14, 1, 0,'RO')
        addVar('samples'      ,0x1c,18, 0,'RO')

        addVar('countEnable'  ,0x28,32, 0,'RO')
        addVar('countAcquire' ,0x2c,32, 0,'RO')
        addVar('countInhibit' ,0x30,32, 0,'RO')
        addVar('countRead'    ,0x34,32, 0,'RO')
        addVar('countStart'   ,0x38,32, 0,'RO')
        addVar('countQueue'   ,0x3c,32, 0,'RO')

        addVar('cacheSel'     ,0x40, 4, 0,'RW')
        addVar('streamSel'    ,0x40, 2, 4,'RW')

        addEnum('cacheState'   ,0x44, 4, 0,'RO',{0:'Empty',1:'Open',2:'Closed',3:'Reading',4:'Last'})
        addEnum('cacheTrigd'   ,0x44, 4, 4,'RO',{0:'Wait',1:'Accept',2:'Reject'})

        addVar('cacheSkip'    ,0x44, 1, 8,'RO')
        addVar('cacheOflow'   ,0x44, 1, 9,'RO')
        addVar('cacheTag'     ,0x44, 5,16,'RO')
        addVar('cacheBaddr'   ,0x48,16, 0,'RO')
        addVar('cacheEaddr'   ,0x48,16,16,'RO')

        addEnum('buildState'   ,0x4c, 3, 0,'RO',{0:'Wait',1:'Idle',2:'ReadHdr',3:'WriteHdr',4:'ReadChan',5:'Dump'})

        addVar('buildDumps'   ,0x4c, 4, 4,'RO')
        addVar('buildHdrv'    ,0x4c, 1, 8,'RO')
        addVar('buildValid'   ,0x4c, 1, 9,'RO')
        addVar('buildReady'   ,0x4c, 1,10,'RO')

        addVar('localId'      ,0x68,32, 0,'RW')

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

        addVar('beginRow'   ,0x00,14, 0,'RW')
        addVar('gateRow'    ,0x04,14, 0,'RW')
        addVar('prescale'   ,0x00,10,20,'RW')
        addVar('aFullRows'  ,0x08,16, 0,'RW')
        addVar('aFullEvents',0x08, 5,16,'RW')
        addVar('freeRows'   ,0x0C,16, 0,'RO')
        addVar('freeEvents' ,0x0C, 5,16,'RO')
        addVar('countOflow' ,0x0C, 8,24,'RO')

class FexCfg(pr.Device):
    def __init__(   self,
                    name        = "FexCfg",
                    description = "Feature extraction config",
                    nstreams    = 2,
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

        addVar('enabledStreams',0x00,nstreams, 0,'RW')
        addVar('almostFullN'   ,0x00,       5, 8,'RW')
        addVar('cntOflow'      ,0x04,       8, 0,'RO')
        addVar('nstreams'      ,0x04,       4,28,'RO')
        addVar('streamMask'    ,0x08,nstreams, 0,'RO')
        addVar('currentStream' ,0x08,       3, 5,'RO')
        addVar('streamValids'  ,0x08,nstreams, 8,'RO')
        addVar('slaveReady'    ,0x08,       1,13,'RO')
        addVar('masterValid'   ,0x08,       1,14,'RO')
        addVar('slaveReady2'   ,0x08,       1,15,'RO')
        addVar('addrRd'        ,0x08,      16,16,'RO')
        addVar('npend'         ,0x0C,       5, 0,'RO')
        addVar('ntrig'         ,0x0C,       5, 5,'RO')
        addVar('nread'         ,0x0C,       5,10,'RO')
        addVar('addrWr'        ,0x0C,      16,16,'RO')

        for i in range(nstreams):
            self.add(StreamBase(
                name = 'StreamBase[%d]'%i,
                offset = 0x10 + 0x10*i))
            if i<4:
                addVar('streamChan[%d]'%i, 0x110+i*0x100, 2, 0, 'RW')

class ChipAdcCore(pr.Device):
    def __init__(   self,
            name        = "ChipAdcCore",
            description = "ADC configuration",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(ChipAdcReg(
            name         = 'ChipAdcReg',
            offset       = 0x0000_0000,
            expand       = False,
        ))

        self.add(FexCfg(
            name         = 'FexCfg',
            offset       = 0x0000_1000,
            expand       = False,
        ))

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


class Application(pr.Device):
    def __init__(   self,
            name        = "Application",
            description = "PCIe Lane Container",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(ChipAdcCore(
            name   = 'ChipAdcCore[0]',
            offset = 0,
            expand = False ))

        self.add(ChipAdcCore(
            name   = 'ChipAdcCore[1]',
            offset = 0x0000_2000,
            expand = False ))

#        self.add(Fmc134Ctrl(
#            name   = 'Fmc134Ctrl',
#            offset = 0x0010_8000,
#            expand = False ))

#        self.add(Mmcm(
#            name   = 'MmcmPhaseShift',
#            offset = 0x0010_8800,
#            expand = False ))

        self.add(l2si_core.TriggerEventManager(
            name   = 'TriggerEventManager',
            numDetectors = 2,
            offset = 0x012_0000,
            enLclsI=True,
            enLclsII=False,
            expand = False ))

