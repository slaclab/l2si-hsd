#ifndef HSD_I2cSwitch_hh
#define HSD_I2cSwitch_hh

#include "Globals.hh"
#include "RegProxy.hh"

namespace Pds {
  namespace HSD {
    class I2cSwitch {
    public:
      enum Port { PrimaryFmc=1, SecondaryFmc=2, SFP=4, LocalBus=8 };
      void select(Port);
      void dump () const;
    private:
      Pds::Mmhw::RegProxy _control;
      uint32_t  _reserved[255];
    };
  };
};

#endif
