#ifndef Pds_HSD_I2cProxy_hh
#define Pds_HSD_I2cProxy_hh

#include <stdint.h>

namespace Pds {
  namespace HSD {
    class I2cProxy {
    public:
      static void initialize(void* base,
                             void* csr);
    public:
      I2cProxy& operator=(const unsigned);
      operator unsigned() const;
    private:
      uint32_t _reserved;
    };
  };
};

#endif
