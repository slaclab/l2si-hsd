#ifndef HSD_RingBuffer_hh
#define HSD_RingBuffer_hh

#include "hsd/RegProxy.hh"

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class RingBuffer {
    public:
      RingBuffer() {}
    public:
      void     enable (bool);
      void     clear  ();
      void     dump   ();
    private:
      RegProxy   _csr;
      RegProxy   _dump[0x1fff];
    };
  };
};

#endif
