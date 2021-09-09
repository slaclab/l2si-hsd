#ifndef HSD_ModuleBase_hh
#define HSD_ModuleBase_hh

#include "TprCore.hh"
//#include "FlashController.hh"
#include "I2c134.hh"

#include "RegProxy.hh"
#include "RingBuffer.hh"
#include "Xvc.hh"

typedef volatile uint32_t vuint32_t;

namespace Pds {
  namespace HSD {
    class ModuleBase {
    public:
      void setRxAlignTarget(unsigned);
      void setRxResetLength(unsigned);
      void dumpRxAlign     () const;
    public:
      static unsigned local_id(unsigned bus); 
      static ModuleBase* create(int);
    public:
      // AxiPcieCore
      uint32_t         rsvd_to_0x020000[(0x20000)/4];

      //uint32_t         rsvd_to_0x060000[(0x40000)/4 - sizeof(version)];
      //AxiStreamMonAxiL dmaIbAxisMon;
      //uint32_t         rsvd_to_0x070000[(0x10000)/4 - sizeof(dmaIbAxisMon)];
      //AxiStreamMonAxiL dmaObAxisMon;
      //uint32_t         rsvd_to_0x0A0000[(0x20000-sizeof(dmaObAxisMon))/4];
      uint32_t          rsvd_to_0x080000[(0x060000)/4];
      //FlashController   flash;
      //uint32_t          rsvd_to_0x090000[(0x010000-sizeof(flash))/4];
      uint32_t          rsvd_to_0x090000[(0x010000)/4];
      Pds::Mmhw::Jtag   jtag;
      uint32_t          rsvd_to_0x0A0000[(0x010000-sizeof(jtag))/4];

      // I2C
      I2c134    i2c;
      uint32_t rsvd_to_0x0A8000[(0x08000-sizeof(i2c))/4];
      uint32_t  regProxy[(0x08000)/4];
      //uint32_t rsvd_to_0x0B0000[(0x08000-sizeof(regProxy))/4];

      // GTH
      uint32_t gthAlign[10];     // 0xB0000
      uint32_t rsvd_to_0xB0100  [54];
      uint32_t gthAlignTarget;
      uint32_t gthAlignLast;
      uint32_t rsvd_to_0x0B0200[62];
      uint32_t rsvd_to_0x0C0000[(0x0FE00)/4];

      // TIM
      Pds::HSD::TprCore  tpr;     // 0xC0000
      uint32_t rsvd_to_0x0D0000  [(0x010000-sizeof(tpr))/4];

      Pds::Mmhw::RingBuffer         ring0;   // 0xD0000
      uint32_t rsvd_to_0x0E0000  [(0x10000-sizeof(ring0))/4];

      Pds::Mmhw::RingBuffer         ring1;   // 0xE0000
      uint32_t rsvd_to_0x0F0000  [(0x10000-sizeof(ring1))/4];
      uint32_t rsvd_to_0x100000[(0x010000)/4];
    };
  };
};

#endif
