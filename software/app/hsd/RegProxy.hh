#ifndef Pds_HSD_RegProxy_hh
#define Pds_HSD_RegProxy_hh

#include <stdint.h>

namespace Pds {
  namespace HSD {
    class RegProxy {
    public:
      static void initialize(int fd, const void* base=0);
    public:
      RegProxy& operator=(const unsigned);
      RegProxy& operator|=(const unsigned);
      RegProxy& operator&=(const unsigned);
      operator unsigned() const;
    private:
      uint32_t _reserved;
    };
  };
};

#endif
