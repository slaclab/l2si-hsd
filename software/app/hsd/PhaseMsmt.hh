#ifndef HSD_PhaseMsmt_hh
#define HSD_PhaseMsmt_hh

#include "hsd/RegProxy.hh"

namespace Pds {
  namespace HSD {
    class PhaseMsmt {
    private:
      uint32_t rsvd[8];
    public:
      RegProxy phaseA_even;
      RegProxy phaseA_odd;
      RegProxy phaseB_even;
      RegProxy phaseB_odd;
      RegProxy countA_even;
      RegProxy countA_odd;
      RegProxy countB_even;
      RegProxy countB_odd;
    private:
      uint32_t reserved[(0x800-64)/4];
    };
  };
};

#endif
