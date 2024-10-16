#-----------------------------------------------------------------------------
# This file is part of the 'snl-trans-fes'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'snl-trans-fes', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue  as pr
import pyrogue.protocols
import pyrogue.utilities.fileio

import rogue
import rogue.hardware.axi
import rogue.interfaces.stream
import rogue.utilities.fileio
import surf.axi             as axi
import axipcie       as pcie
import hsd_6400m_dma_nc_115 as hsd_6400m

rogue.Version.minVersion('6.1.3')

class Root(pr.Root):
    def __init__(   self,
            dev      = '/dev/datadev_0',
            pollEn   = True,  # Enable automatic polling registers
            initRead = True,  # Read all registers at start of the system
            zmqSrvEn = True,  # Flag to include the ZMQ server
            defaultFile    = "config/config1.yml",
            h5Path   = None,
            **kwargs):

        # Pass custom value to parent via super function
        super().__init__(**kwargs)

        if zmqSrvEn:
            self.zmqServer = pyrogue.interfaces.ZmqServer(root=self, addr='127.0.0.1', port=0)
            self.addInterface(self.zmqServer)

        self.defaultFile    = defaultFile
        # Check for simulation
        self.sim  = (dev == 'sim')
        if self.sim:
            # Set the timeout
            self._timeout = 100000000 # firmware simulation slow and timeout base on real time (not simulation time)
        else:
            # Set the timeout
            self._timeout = 5000000 # 5.0 seconds default

        #################################################################

        # Check if not VCS simulation
        if (not self.sim):

            # Start up flags
            self._pollEn   = pollEn
            self._initRead = initRead

            # Create PCIE memory mapped interface
            self.memMap = pcie.createAxiPcieMemMap(dev, 'localhost', 8000)
            # self.memMap = rogue.hardware.axi.AxiMemMap(dev)

            # Map the DMA streams
            self.dmaStream = rogue.hardware.axi.AxiStreamDma(dev,(0x100*0)+0,1)

        # Else running the VCS simulation
        else:

            # Start up flags are FALSE for simulation mode
            self._pollEn   = False
            self._initRead = False

            # Create PCIE memory mapped interface
            self.memMap = rogue.hardware.axi.AxiMemMap(dev) #pcie.createAxiPcieMemMap(dev, 'localhost', 8000)

            # Map the simulation DMA streams
            self.dmaStream = rogue.interfaces.stream.TcpClient('localhost',10000+2*0) # 2 TCP ports per stream

        #################################################################
        #################################################################

            
        # Add the PCIe core device to base
        self.add(pcie.AxiPcieCore(
            offset      = 0x0000_0000,
            memBase     = self.memMap,
            numDmaLanes = 2,
            sim         = self.sim,
            expand      = True,
        ))

        # I2C   @0x000A_0000
        self.add(hsd_6400m.I2c134(
            name   = 'I2cBus',
            offset = 0x000A_0000,
            memBase     = self.memMap,
            expand = False))


        # Add the Application device to base
        self.add(hsd_6400m.Application(
            offset      = 0x0010_0000,
            memBase     = self.memMap,
            sim         = self.sim,
            expand      = True,
        ))


        #################################################################

        # Create PreProcessing Tester RX/TX
        # self.add(lclsHsdtokenizer.PreProcessingTester(
        #     root   = self,
        #     h5Path = h5Path,
        #     expand = True,
        # ))

        # Create a Fifo with maxDepth=100, trimSize=0, noCopy=True
        self.fifoTx = rogue.interfaces.stream.Fifo(100, 0, True)
        self.fifoRx = rogue.interfaces.stream.Fifo(100, 0, True)

        # Connect PreProcessing Tester RX/TX to DMA stream
        # self.PreProcessingTester >> self.fifoTx >> self.dmaStream
        # self.PreProcessingTester << self.fifoRx << self.dmaStream

        #################################################################

    def start(self, **kwargs):
        super().start(**kwargs)

        # Check if not simulation
        if not self.sim:
            # Refresh the software shadow variables
            self.ReadAll()

            # Load the YAML configuration
            print(f'Loading {self.defaultFile} Configuration File...')
            self.LoadConfig(self.defaultFile)
            # set clks
            print('set clks')
            self.I2cBus.set_134_clk('PrimaryFmc')
            # self.Application.I2cBus.fmcCpld.default_clocktree_init(0)
            # print('set adc')
            self.I2cBus.set_134_adc('PrimaryFmc')
            print('done')