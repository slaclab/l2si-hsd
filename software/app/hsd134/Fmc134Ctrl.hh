#ifndef HSD_Fmc134Ctrl_hh
#define HSD_Fmc134Ctrl_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class Fmc134Cpld;
    class Fmc134Ctrl {
    public:
      void    remote_sync ();
      int32_t default_init(Fmc134Cpld&, unsigned mode=0);
      int32_t reset       ();
      void dump();
    public:
      Pds::Mmhw::Reg info;
      Pds::Mmhw::Reg xcvr;
      Pds::Mmhw::Reg status;
      Pds::Mmhw::Reg adc_val;
      Pds::Mmhw::Reg scramble;
      Pds::Mmhw::Reg sw_trigger;
      Pds::Mmhw::Reg lmfc_cnt;
      Pds::Mmhw::Reg align_char;
      Pds::Mmhw::Reg adc_pins;
      Pds::Mmhw::Reg adc_pins_r;
      Pds::Mmhw::Reg test_clksel;
      Pds::Mmhw::Reg test_clkfrq;
    };
  };
};

#endif
