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
import rogue
import click

import l2si_hsd as hsd
import axipcie

#import lcls2_pgp_fw_lib.hardware.shared as shared

import surf.protocols.batcher as batcher
import l2si_core              as l2si

rogue.Version.minVersion('4.10.3')
# rogue.Version.exactVersion('4.10.3')

class HsdDevRoot(shared.Root):

    def __init__(self,
                 dataDebug   = False,
                 dev         = '/dev/datadev_0',# path to PCIe device
                 pollEn      = True,            # Enable automatic polling registers
                 initRead    = True,            # Read all registers at start of the system
                 dmaLanes    = 1,
                 defaultFile = None,
                 devTarget = hsd.Hsd6400mSolo,
                 **kwargs):

        # Set the firmware Version lock = firmware/targets/shared_version.mk
#        self.FwVersionLock = 0x04020000

        self.dev         = dev

        # Check for simulation
        if dev == 'sim':
            kwargs['timeout'] = 100000000 # 100 s
        else:
            kwargs['timeout'] = 5000000 # 5 s

        # Pass custom value to parent via super function
        super().__init__(
            dev         = dev,
            pollEn      = pollEn,
            initRead    = initRead,
            **kwargs)

        # Create memory interface
        self.memMap = axipcie.createAxiPcieMemMap(dev, 'localhost', 8000)

        # Instantiate the top level Device and pass it the memory map
        self.add(devTarget(
            name     = 'HsdPcie',
            memBase  = self.memMap,
            expand   = True,
        ))

        # Create DMA streams
        self.dmaStreams = axipcie.createAxiPcieDmaStreams(dev, {lane:{0} for lane in range(dmaLanes)}, 'localhost', 8000)

        # Create arrays to be filled
        self._dbg = [None for lane in range(dmaLanes)]
        self.unbatchers = [rogue.protocols.batcher.SplitterV1() for lane in range(dmaLanes)]

        # Create the stream interface
        for lane in range(dmaLanes):
            # Debug slave
            if dataDebug:
                # Connect the streams
                self.dmaStreams[lane][1] >> self.unbatchers[lane] >> self._dbg[lane]

    def start(self, **kwargs):
        super().start(**kwargs)

        # Hide all the "enable" variables
        for enableList in self.find(typ=pr.EnableVariable):
            # Hide by default
            enableList.hidden = True

        # Check if simulation
        if (self.dev=='sim'):
            pass

        else:
            # Read all the variables
            self.ReadAll()

            # Check for PCIe FW version
            fwVersion = self.HsdPcie.AxiPcieCore.AxiVersion.FpgaVersion.get()
            if (fwVersion != self.FwVersionLock):
                errMsg = f"""
                    PCIe.AxiVersion.FpgaVersion = {fwVersion:#04x} != {self.FwVersionLock:#04x}
                    Please update PCIe firmware using software/scripts/updatePcieFpga.py
                    """
                click.secho(errMsg, bg='red')
                raise ValueError(errMsg)

        # Load the configurations
        if self.defaultFile is not None:
            defaultFile = ["config/defaults.yml",self.defaultFile]
            # defaultFile = [self.defaultFile]
            print(f'Loading {defaultFile} Configuration File...')
            self.LoadConfig(defaultFile)

    # Function calls after loading YAML configuration
    def initialize(self):
        super().initialize()
#        self.StopRun()
#        self.CountReset()
