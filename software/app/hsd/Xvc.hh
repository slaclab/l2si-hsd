#ifndef Pds_HSD_Xvc_hh
#define Pds_HSD_Xvc_hh

#include "hsd/RegProxy.hh"

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class Jtag {
    public:
      RegProxy  length_offset;
      RegProxy  tms_offset;
      RegProxy  tdi_offset;
      RegProxy  tdo_offset;
      RegProxy  ctrl_offset;
    };

    class Xvc {
    public:
      static void* launch(Jtag*,
                          unsigned short port=2542,
                          bool           lverbose=false);
    };
  };
};

#endif
