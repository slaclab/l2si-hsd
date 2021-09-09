#ifndef HSD_AdcSync_hh
#define HSD_AdcSync_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class AdcSync {
    public:
      void set_delay     (const unsigned*);
      void start_training();
      void stop_training ();
      void dump_status   () const;
    private:
      Pds::Mmhw::Reg _cmd;
      //  cmd
      //  b0 = calibrate
      //  b15:1  = calib_time
      //  b19:16 = delay load
      mutable Pds::Mmhw::Reg _select;
      //  select
      //  b1:0 = channel for readout
      //  b7:4 = word for readout
      Pds::Mmhw::Reg _match;
      Pds::Mmhw::Reg _rsvd;
      Pds::Mmhw::Reg _delay[8];
      Pds::Mmhw::Reg _rsvd2[0x1f4];
    };
  };
};

#endif
