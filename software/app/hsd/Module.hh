#ifndef HSD_Module_hh
#define HSD_Module_hh

#include "hsd/Globals.hh"
#include "hsd/AxiVersion.h"
#include <stdint.h>
#include <stdio.h>

namespace Pds {
  namespace HSD {
    class TprCore;
    class FexCfg;
    class Jtag;
    class PhaseMsmt;

    class Module {
    public:
      //
      //  High level API
      //
      static Module* create(int fd, unsigned fmc);
      static Module* create(int fd, unsigned fmc, TimingType);
      
      ~Module();

      int      fd() const { return _fd; }
      unsigned fmc() const { return _fmc; }

      uint64_t device_dna() const;

      void board_status();

      void flash_write(FILE*);

      //  Initialize busses
      void init();

      unsigned ncards() const;

      //  Initialize clock tree and IO training
      void fmc_init          (TimingType =LCLS);
      void fmc_clksynth_setup(TimingType =LCLS);
      void fmc_dump();

      int  train_io(unsigned);

      enum TestPattern { Ramp=0, Flash11=1, Flash12=3, Flash16=5, DMA=8 };
      void enable_test_pattern(TestPattern);
      void disable_test_pattern();
      void enable_cal ();
      void disable_cal();

      void sample_init (unsigned length,
                        unsigned delay,
                        unsigned prescale,
                        int      onechannel_input,
                        unsigned streams);

      void trig_lcls  (unsigned eventcode);
      void sync       ();
      void start      ();
      void stop       ();

      //  Calibration
      unsigned get_offset(unsigned channel);
      unsigned get_gain  (unsigned channel);
      void     set_offset(unsigned channel, unsigned value);
      void     set_gain  (unsigned channel, unsigned value);

      AxiVersion version() const;
      Pds::HSD::TprCore&    tpr    ();
      Pds::HSD::Jtag&       jtag();
      Pds::HSD::PhaseMsmt&  phasemsmt();

      void setRxAlignTarget(unsigned);
      void setRxResetLength(unsigned);
      void dumpRxAlign     () const;
      void dumpPgp         () const;
      void dumpBase        () const;
      void dumpMap         () const;
      void dumpStatus      () const;

      FexCfg* fex();

      int read(void* data, unsigned data_size);

      void* reg();
    private:
      Module() {}

      class PrivateData;
      PrivateData* p;

      int _fd;
      unsigned _fmc;
    };
  };
};

#endif
