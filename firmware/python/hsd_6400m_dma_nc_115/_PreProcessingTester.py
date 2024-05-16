#-----------------------------------------------------------------------------
# This file is part of the 'snl-trans-fes'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'snl-trans-fes', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import rogue.interfaces.stream
import pyrogue as pr
import numpy as np
import click
import pyrogue
import struct
import h5py
import time

class PreProcessingTester(pr.Device, rogue.interfaces.stream.Master, rogue.interfaces.stream.Slave):

    def __init__(self,root=None,h5Path=None,**kwargs):
        pr.Device.__init__(self, **kwargs)
        rogue.interfaces.stream.Slave.__init__(self)
        rogue.interfaces.stream.Master.__init__(self)
        self.activeTest = False

        self.h5Path            = h5Path

        # 1024 samples x 160 channels x 32-bit float / (8b/B)
        # self.ibSize = 1024*160*32//8

        # 512-bit sample / (8b/B)
        self.obSize = 512//8

        # Initialize the local variables
        self.numRxLanes = 2
        self.dataOut   = [None  for x in range(15)]


    # Method which is called when a frame is received
    def _acceptFrame(self,frame):

        # First it is good practice to hold a lock on the frame data.
        with frame.lock():

            # Next we can get the size of the frame payload
            size = frame.getPayload()
            # print( f'obFrame.getPayload() = {size} bytes' )

            # Check if the expected size match the received size
            if (self.obSize != size):
                click.secho( f'Expected Size={self.obSize} != obFrame.getPayload()={size}' , bg='red')
                return

            # Init the variable
            ba = bytearray(4) # 4 bytes = 32-bits

            # Loop through bytes of data
            for j in range(15): # 512-bit word (480-bit actual data); 480-bit /32-bit bytearray = 15 
                # Read 4 bytes
                frame.read(ba, 4*j)
                # convert into `unsigned int`
                result = struct.unpack('<I', ba)
                self.dataOut[j] = result


    # Overload the `==` python operator for a bi-directional connection for this custom master/slave stream module
    def __eq__(self,other):
        pyrogue.streamConnectBiDir(other,self)

    def __rshift__(self,other):
        pyrogue.streamConnect(self,other)
        return other

    def __lshift__(self,other):
        pyrogue.streamConnect(other,self)
        return other
