#ifndef HSD_ClkSynth_hh
#define HSD_ClkSynth_hh

#include "hsd/Globals.hh"
#include "hsd/I2cProxy.hh"
#include <stdint.h>
#include <stdio.h>

namespace Pds {
  namespace HSD {
    class ClkSynth {
    public:
      void dump () const;
      void setup(TimingType);
    public:
      I2cProxy _reg[256];
    };
  };
};

#endif
