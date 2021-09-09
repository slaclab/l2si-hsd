#ifndef Pds_HSD_TprCore_hh
#define Pds_HSD_TprCore_hh

#include "Globals.hh"
#include "Reg.hh"
#include <stdint.h>

namespace Pds {
  namespace HSD {
    class TprCore {
    public:
      bool rxPolarity () const;
      void rxPolarity (bool p);
      void resetRx    ();
      void resetRxPll ();
      void resetBB    ();
      void resetCounts();
      void setLCLS    ();
      void setLCLSII  ();

      double txRefClockRate() const;
      double rxRecClockRate() const;
      void   dump() const;
    public:
      Pds::Mmhw::Reg SOFcounts;
      Pds::Mmhw::Reg EOFcounts;
      Pds::Mmhw::Reg Msgcounts;
      Pds::Mmhw::Reg CRCerrors;
      Pds::Mmhw::Reg RxRecClks;
      Pds::Mmhw::Reg RxRstDone;
      Pds::Mmhw::Reg RxDecErrs;
      Pds::Mmhw::Reg RxDspErrs;
      Pds::Mmhw::Reg CSR;
      uint32_t  reserved;
      Pds::Mmhw::Reg TxRefClks;
      Pds::Mmhw::Reg BypassCnts;
      Pds::Mmhw::Reg Version;
    };
  };
};

#endif
