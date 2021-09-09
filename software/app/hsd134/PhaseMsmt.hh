#ifndef HSD_PhaseMsmt_hh
#define HSD_PhaseMsmt_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class PhaseMsmt {
    public:
      Pds::Mmhw::Reg phaseA_even;
      Pds::Mmhw::Reg phaseA_odd;
      Pds::Mmhw::Reg phaseB_even;
      Pds::Mmhw::Reg phaseB_odd;
      Pds::Mmhw::Reg countA_even;
      Pds::Mmhw::Reg countA_odd;
      Pds::Mmhw::Reg countB_even;
      Pds::Mmhw::Reg countB_odd;
    };
  };
};

#endif
