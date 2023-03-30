#ifndef OptFmc_hh
#define OptFmc_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class OptFmc {
    public:
      Pds::Mmhw::Reg fmc;
      Pds::Mmhw::Reg qsfp;
      Pds::Mmhw::Reg clks[7];
      Pds::Mmhw::Reg adcOutOfRange[10];
      Pds::Mmhw::Reg phaseCount_0;
      Pds::Mmhw::Reg phaseValue_0;
      Pds::Mmhw::Reg phaseCount_1;
      Pds::Mmhw::Reg phaseValue_1;
    public:
      void resetPgp();
      void dump() const;
    };
  };
};

#endif
