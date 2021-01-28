#ifndef HSD_TriggerEventManager_hh
#define HSD_TriggerEventManager_hh

#include "hsd/RegProxy.hh"

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class EvrV2ChannelReg {
    public:
      RegProxy enable;
      RegProxy ratedestsel; // 13b/19b
      RegProxy count;
    private:
      uint32_t rsvd[61];
    };

    class EvrV2TriggerReg {
    public:
      RegProxy enable; // source[3:0],polarity[16],enable[31]
      RegProxy delay;
      RegProxy width;
    private:
      uint32_t rsvd[61];
    };

    class EvrV2CoreTriggers {
    public:
      EvrV2ChannelReg ch[16];
      EvrV2TriggerReg tr[16];
    };

    class TriggerEventBuffer {
    public:
      RegProxy enable; // enables trigger and header cache
      uint32_t rsvd_to_10[3];
      RegProxy fifocsr; // overflow[2],pause[3],reset[31]
      uint32_t rsvd_to_28[5];
      RegProxy count;
      uint32_t rsvd_to_40[5];
      RegProxy resetCount;
      uint32_t rsvd_to_100[47];
    };

    class TriggerEventManager {
    public:
      void trig_lcls(unsigned eventcode,unsigned chan);
      void start(unsigned chan);
      void stop (unsigned chan);
      void dump (unsigned chan) const;
    private:
      EvrV2CoreTriggers evr;
      uint32_t rsvd_to_9000[(0x9000-sizeof(evr))/4];
      TriggerEventBuffer buffer[8];
    };
  };
};

#endif 
