#ifndef HSD_PhyCore_hh
#define HSD_PhyCore_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {

    class PhyCore {
    public:
      void dump() const;
    public:
      Pds::Mmhw::Reg rsvd_0[0x130/4];
      Pds::Mmhw::Reg bridgeInfo;
      Pds::Mmhw::Reg bridgeCSR;
      Pds::Mmhw::Reg irqDecode;
      Pds::Mmhw::Reg irqMask;
      Pds::Mmhw::Reg busLocation;
      Pds::Mmhw::Reg phyCSR;
      Pds::Mmhw::Reg rootCSR;
      Pds::Mmhw::Reg rootMSI1;
      Pds::Mmhw::Reg rootMSI2;
      Pds::Mmhw::Reg rootErrorFifo;
      Pds::Mmhw::Reg rootIrqFifo1;
      Pds::Mmhw::Reg rootIrqFifo2;
      Pds::Mmhw::Reg rsvd_160[2];
      Pds::Mmhw::Reg cfgControl;
      Pds::Mmhw::Reg rsvd_16c[(0x208-0x16c)/4];
      Pds::Mmhw::Reg barCfg[0x30/4];
      Pds::Mmhw::Reg rsvd_238[(0x1000-0x238)/4];
    };
  };
};

#endif
