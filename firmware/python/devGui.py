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

import os
import sys
import argparse
import importlib
import rogue
import pyrogue.gui
import pyrogue.pydm

if __name__ == "__main__":

#################################################################

    # Set the argument parser
    parser = argparse.ArgumentParser()

    # Convert str to bool
    argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

    # Add arguments
    parser.add_argument(
        "--dev",
        type     = str,
        required = False,
        default  = '/dev/datadev_0',
        help     = "path to device",
    )

    parser.add_argument(
        "--enLclsI",
        type     = argBool,
        required = False,
        default  = True, # Default: Enable LCLS-I hardware registers
        help     = "Enable LCLS-I hardware registers",
    )

    parser.add_argument(
        "--enLclsII",
        type     = argBool,
        required = False,
        default  = False, # Default: Disable LCLS-II hardware registers
        help     = "Enable LCLS-II hardware registers",
    )

    parser.add_argument(
        "--pollEn",
        type     = argBool,
        required = False,
        default  = True,
        help     = "Enable auto-polling",
    )

    parser.add_argument(
        "--initRead",
        type     = argBool,
        required = False,
        default  = True,
        help     = "Enable read all variables at start",
    )

    parser.add_argument(
        "--serverPort",
        type     = int,
        required = False,
        default  = 9099,
        help     = "Zeromq server port",
    )

    # Get the arguments
    args = parser.parse_args()

    #################################################################

    # First see if submodule packages are already in the python path
    try:
        import axipcie
        import hsd_dualv3
        import LclsTimingCore
        import surf

    # Otherwise assume it is relative in a standard development directory structure
    except:
        print('import exception')
        import setup

    # Load the cameralink-gateway package
    #import lcls2_pgp_pcie_apps

    #################################################################

    # Select the hardware type
    devTarget = hsd_dualv3.Pc820
    numLanes  = 2

    #################################################################

    with hsd_dualv3.DevRoot(
            dev            = args.dev,
            pollEn         = args.pollEn,
            initRead       = args.initRead,
            enLclsI        = args.enLclsI,
            enLclsII       = args.enLclsII,
            numLanes       = numLanes,
            devTarget      = devTarget,
        ) as root:

        ######################
        # Development PyDM GUI
        ######################
        pyrogue.pydm.runPyDM(root=root)

    #################################################################
