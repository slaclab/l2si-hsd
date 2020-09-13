#ifndef HSD_Adt7411_hh
#define HSD_Adt7411_hh

#include <stdint.h>

#include "hsd/I2cProxy.hh"

namespace Pds {
  namespace HSD {
    class Adt7411 {
    public:
      unsigned deviceId       () const;
      unsigned manufacturerId () const;
      unsigned interruptStatus() const;
      unsigned interruptMask  () const;
      unsigned internalTemp   () const;
      unsigned externalTemp   () const;
      void     dump           ();
    public:
      void     interruptMask  (unsigned);
    private:
      I2cProxy _reg[256];
    };
  };
};

#endif
