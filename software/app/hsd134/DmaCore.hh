#ifndef HSD_DmaCore_hh
#define HSD_DmaCore_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {

    class DmaCore {
    public:
      void init(unsigned maxDmaSize=0);
      void dump() const;
      Pds::Mmhw::Reg rxEnable;
      Pds::Mmhw::Reg txEnable;
      Pds::Mmhw::Reg fifoClear;
      Pds::Mmhw::Reg irqEnable;
      Pds::Mmhw::Reg fifoValid; // W fifoThres, R b0 = inbound, b1=outbound
      Pds::Mmhw::Reg maxRxSize; // inbound
      Pds::Mmhw::Reg mode;      // b0 = online, b1=acknowledge, b2=ibrewritehdr
      Pds::Mmhw::Reg irqStatus; // W b0=ack, R b0=ibPend, R b1=obPend
      Pds::Mmhw::Reg irqRequests;
      Pds::Mmhw::Reg irqAcks;
      Pds::Mmhw::Reg irqHoldoff;
      Pds::Mmhw::Reg dmaCount;

      Pds::Mmhw::Reg reserved[244];

      Pds::Mmhw::Reg ibFifoPop;
      Pds::Mmhw::Reg obFifoPop;
      Pds::Mmhw::Reg reserved_pop[62];

      Pds::Mmhw::Reg loopFifoData; // RO
      Pds::Mmhw::Reg reserved_loop[63];

      Pds::Mmhw::Reg ibFifoPush[16];  // W data, R[0] status
      Pds::Mmhw::Reg obFifoPush[16];  // R b0=full, R b1=almost full, R b2=prog full
      Pds::Mmhw::Reg reserved_push[32];
    };
  };
};

#endif
