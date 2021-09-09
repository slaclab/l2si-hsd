#ifndef HSD_AdcCore_hh
#define HSD_AdcCore_hh

#include "RegProxy.hh"
#include <stdint.h>

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
      RegProxy _cmd;
      RegProxy _status;
      RegProxy _master_start;
      RegProxy _adrclk_delay_set_auto;
      RegProxy _channel_select;
      RegProxy _tap_match_lo;
      RegProxy _tap_match_hi;
      RegProxy _adc_req_tap ;
      RegProxy _rsvd2[0xf8];
    };
  };
};

#endif
