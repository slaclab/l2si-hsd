#ifndef HSD_I2c134_hh
#define HSD_I2c134_hh

#include "Globals.hh"
#include "I2cSwitch.hh"
#include "ClkSynth.hh"
#include "LocalCpld.hh"
#include "Fmc134Cpld.hh"
#include "Adt7411.hh"
#include "Ad7291.hh"
#include "Tps2481.hh"

namespace Pds {
  namespace HSD {
    class I2c134 {
    public:
      //   Need to make sure the i2cswitch is locked during access
      I2cSwitch  i2c_sw_control;  // 0x10000
      ClkSynth   clksynth;        // 0x10400
      LocalCpld  local_cpld;      // 0x10800
      Adt7411    vtmon1;          // 0x10C00
      Adt7411    vtmon2;          // 0x11000
      Adt7411    vtmon3;          // 0x11400
      Tps2481    imona;           // 0x11800
      Tps2481    imonb;           // 0x11C00
      Ad7291     fmcadcmon;       // 0x12000
      Ad7291     fmcvmon;         // 0x12400
      Fmc134Cpld fmc_cpld;        // 0x12800 
      Pds::Mmhw::RegProxy   eeprom[0x100];   // 0x12C00
    };
  };
};

#endif
