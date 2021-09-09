#ifndef HSD_Tsp2481_hh
#define HSD_Tsp2481_hh

#include <stdint.h>

#include "I2cProxy.hh"

namespace Pds {
  namespace HSD {
    class Tps2481 {
    public:
      void     dump           ();
    private:
      I2cProxy _cfg;
      I2cProxy _shtv;
      I2cProxy _busv;
      I2cProxy _pwr;
      I2cProxy _cur;
      I2cProxy _cal;
      I2cProxy _reg[250];
    };
  };
};

#endif
