#ifndef HSD_LocalCpld_hh
#define HSD_LocalCpld_hh

#include <stdint.h>

#include "hsd/I2cProxy.hh"

namespace Pds {
  namespace HSD {
    class LocalCpld {
    public:
      unsigned revision  () const;
      unsigned GAaddr    () const;
    public:
      void     reloadFpga();
      void     GAaddr    (unsigned);
    private:
      I2cProxy          _reg[256];
    };
  };
};

#endif
