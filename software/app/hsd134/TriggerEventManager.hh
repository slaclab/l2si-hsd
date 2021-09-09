#ifndef Pds_TriggerEventManager_hh
#define Pds_TriggerEventManager_hh

#include "Reg.hh"
#include <stdint.h>

namespace Pds {
  namespace Mmhw {
    class XpmMessageAligner {
    public:
      XpmMessageAligner() {}
    public:
      Reg messageDelay[8];
      Reg txId;
      Reg rxId;
      uint32_t reserved_28[(0x100-0x28)>>2];
    };

    class TriggerEventBuffer {
    public:
      TriggerEventBuffer() {}
    public:
      void start  (unsigned group,
                   unsigned triggerDelay=10,
                   unsigned pauseThresh=16);
      void stop   ();
    public:
      Reg enable;
      Reg group;
      Reg pauseThresh;
      Reg triggerDelay;
      Reg status;
      Reg l0Count;
      Reg l1AcceptCount;
      Reg l1RejectCount;
      Reg transitionCount;
      Reg validCount;
      Reg triggerCount;
      Reg currPartitionBcast;
      Reg currPartitionWord0Lo;
      Reg currPartitionWord0Hi;
      Reg fullToTrig;
      Reg nfullToTrig;
      Reg resetCounters;
      uint32_t reserved_44[(0x100-0x44)>>2];
    };

    class TriggerEventManager {
    public:
      TriggerEventManager() {}
    public:
      XpmMessageAligner&  xma() { return _xma; }
      TriggerEventBuffer& det(unsigned i) { return reinterpret_cast<TriggerEventBuffer*>(this+1)[i]; }
    private:
      XpmMessageAligner _xma;
    };
  };
};

#endif
