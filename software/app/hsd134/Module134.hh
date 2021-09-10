#ifndef HSD_Module134_hh
#define HSD_Module134_hh

#include "EnvMon.hh"
#include "Globals.hh"
#include "I2cSwitch.hh"
#include <string>
#include <stdint.h>
#include <stdio.h>
#include <vector>
#include <semaphore.h>

namespace Pds {
  namespace Mmhw {
    class Jtag;
    class TriggerEventManager2;
  };
  namespace HSD {
    class TprCore;
    class Fmc134Ctrl;
    class FexCfg;
    class Mmcm;
    class Jesd204b;
    class I2c134;
    class ChipAdcCore;
    class OptFmc;

    class FexParams {
    public:
      unsigned lo_threshold;
      unsigned hi_threshold;
      unsigned rows_before;
      unsigned rows_after;
    };

    //
    //  High level API
    //
    class Module134 {
    public:
      static Module134* create(int fd);
      static Module134* create(void*);

      ~Module134();

      I2c134&                      i2c    ();
      ChipAdcCore&                 chip   (unsigned ch);
      Pds::Mmhw::TriggerEventManager2& tem    ();
      Fmc134Ctrl&                  jesdctl();
      Mmcm&                        mmcm   ();
      TprCore&                     tpr    ();

      Jesd204b&                    jesd   (unsigned ch);
      OptFmc&                      optfmc ();
      void*                        reg    ();
      Pds::Mmhw::Jtag&             xvc    ();

      //  Accessors
      uint64_t device_dna() const;

      void     setup_timing();
      void     setup_jesd  (bool lAbortOnErr,
                            std::string& calib_adc0,
                            std::string& calib_adc1,
                            bool         lDualCh=false,
                            InputChan    inputCh=CHAN_A0_2);
      void     write_calib (const char*);
      void     board_status();

      void     set_local_id(unsigned bus);
      unsigned remote_id   () const;

      enum TestPattern { PRBS7=1, PRBS15=2, PRBS23=3, Ramp=4, Transport=5, D21_5=6,
                         K28_5=7, ILA=8, RPAT=9, SO_LO=10, SO_HI=11 };
      void     enable_test_pattern(Module134::TestPattern);
      void     disable_test_pattern();

      void sample_init (unsigned length,
                        unsigned delay,
                        unsigned prescale,
                        int      onechannel_input,
                        unsigned streams);

      void sample_init (unsigned length,
                        unsigned delay,
                        unsigned prescale,
                        int      onechannel_input,
                        unsigned streams,
                        const FexParams& params);

      void trig_lcls  (unsigned eventcode);
      void sync       ();
      void start      ();
      void stop       ();

      void     dumpRxAlign     () const;
      void     dumpMap         () const;

      //  Monitoring
      void     mon_start();
      EnvMon   mon() const;

      void     i2c_lock  (I2cSwitch::Port) const;
      void     i2c_unlock() const;
    private:
      Module134();

      void     _jesd_init(unsigned);

      class PrivateData;
      PrivateData*      p;

      int               _fd;
      mutable sem_t     _sem_i2c;
    };
  };
};

#endif
