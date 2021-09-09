#ifndef HSD_HdrFifo_hh
#define HSD_HdrFifo_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class HdrFifo {
    public:
      Pds::Mmhw::Reg _wrFifoCnt;
      Pds::Mmhw::Reg _rdFifoCnt;
    };
  };
};

#endif
