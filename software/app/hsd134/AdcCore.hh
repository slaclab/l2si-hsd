#ifndef HSD_AdcCore_hh
#define HSD_AdcCore_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class AdcCore {
    public:
      void init_training (unsigned);
      void start_training();
      void dump_training ();
      void loop_checking ();
      void capture_idelay();
      void pulse_sync    ();
      void set_ref_delay (unsigned);
      void dump_status   () const;
    private:
      Pds::Mmhw::Reg _cmd;
      Pds::Mmhw::Reg _status;
      Pds::Mmhw::Reg _master_start;
      Pds::Mmhw::Reg _adrclk_delay_set_auto;
      Pds::Mmhw::Reg _channel_select;
      Pds::Mmhw::Reg _tap_match_lo;
      Pds::Mmhw::Reg _tap_match_hi;
      Pds::Mmhw::Reg _adc_req_tap ;
      Pds::Mmhw::Reg _rsvd2[0xf8];
    };
  };
};

#endif
