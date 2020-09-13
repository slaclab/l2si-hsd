/**
 *-----------------------------------------------------------------------------
 * Title      : Data Development Card Driver, Shared Header
 * ----------------------------------------------------------------------------
 * File       : DataDriver.h
 * Created    : 2017-03-21
 * ----------------------------------------------------------------------------
 * Description:
 * Defintions and inline functions for interacting with Data Development driver.
 * ----------------------------------------------------------------------------
 * This file is part of the aes_stream_drivers package. It is subject to 
 * the license terms in the LICENSE.txt file found in the top-level directory 
 * of this distribution and at: 
 *    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
 * No part of the aes_stream_drivers package, including this file, may be 
 * copied, modified, propagated, or distributed except according to the terms 
 * contained in the LICENSE.txt file.
 * ----------------------------------------------------------------------------
**/
#ifndef __DATA_DRIVER_H__
#define __DATA_DRIVER_H__
#include <hsd/AxisDriver.h>
#include <hsd/DmaDriver.h>
#include <hsd/FpgaProm.h>
#include <hsd/AxiVersion.h>

#define dmaDest(lane,vc) ((lane<<8) | vc)

#endif

