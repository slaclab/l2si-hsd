#ifndef HSD_FmcCore_hh
#define HSD_FmcCore_hh

#include "Globals.hh"
#include "Reg.hh"

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
      Pds::Mmhw::Reg _irq;
      Pds::Mmhw::Reg _irq_en;
      Pds::Mmhw::Reg _rsvd[6];
      Pds::Mmhw::Reg _detect;
      Pds::Mmhw::Reg _cmd;
      Pds::Mmhw::Reg _ctrl;
      Pds::Mmhw::Reg _rsvd2[5];
      Pds::Mmhw::Reg _clock_select;
      Pds::Mmhw::Reg _clock_count;
      Pds::Mmhw::Reg _rsvd3[0xee];
    };
  };
};

#endif
