#ifndef HSD_FmcCore_hh
#define HSD_FmcCore_hh

#include "RegProxy.hh"
#include <stdint.h>

namespace Pds {
  namespace HSD {
    class FmcCore {
    public:
      bool   present  () const;
      bool   powerGood() const;
      void   selectClock(unsigned);
      double clockRate() const;
      void   cal_enable ();
      void   cal_disable();
    private:
      RegProxy _irq;
      RegProxy _irq_en;
      RegProxy _rsvd[6];
      RegProxy _detect;
      RegProxy _cmd;
      RegProxy _ctrl;
      RegProxy _rsvd2[5];
      RegProxy _clock_select;
      RegProxy _clock_count;
      RegProxy _rsvd3[0xee];
    };
  };
};

#endif
