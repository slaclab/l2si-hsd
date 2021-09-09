#ifndef Pds_HSD_TprCore_hh
#define Pds_HSD_TprCore_hh

#include "RegProxy.hh"

#include <unistd.h>
#include <stdint.h>

namespace Pds {
  namespace HSD {
    class TprCore {
    public:
      bool rxPolarity () const;
      void rxPolarity (bool p);
      void resetRx    ();
      void resetRxPll ();
      void resetCounts();
      void setLCLS    ();
      void setLCLSII  ();
      void dump() const;
    public:
      RegProxy SOFcounts;
      RegProxy EOFcounts;
      RegProxy Msgcounts;
      RegProxy CRCerrors;
      RegProxy RxRecClks;
      RegProxy RxRstDone;
      RegProxy RxDecErrs;
      RegProxy RxDspErrs;
      RegProxy CSR;
      uint32_t reserved;
      RegProxy TxRefClks;
      RegProxy BypassCnts;
      RegProxy Version;
    };
  };
};

#endif
