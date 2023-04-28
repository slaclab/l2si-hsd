#ifndef Pds_EvrV2CoreTriggers_hh
#define Pds_EvrV2CoreTriggers_hh

//
//  Modified layout from original TEM
//
#include <stdint.h>

namespace Pds {
  namespace Mmhw {
      class EvrV2Channel {
      public:
          void disable() {
              _enable = 0;
          }
          void enable(unsigned code) {
              _select = (0x20000 << 13) | (0x1000) | (code & 0x1ff);
              _enable = 1;
          }
          enum FixedRate { _1Hz, _10Hz, _100Hz, _1kHz, _10kHz, _71kHz, _1MHz };
          void enable(FixedRate r) {
              _select = (0x20000 << 13) | (r & 0xf);
              _enable = 1;
          }
          enum ACRate { _1HzAC, _5HzAC, _10HzAC, _30HzAC, _60HzAC };
          void enable(ACRate r, unsigned tsmask) { // (tsmask&1)=timeslot 1
              _select = (0x20000 << 13) | (0x0800) | (tsmask<<3) | (r & 0x7);
              _enable = 1;
          }
      public:
          Reg               _enable;
          Reg               _select;
          Reg               _counts;
          uint32_t          _rsvd[61];
      };

      class EvrV2Trig {
      public:
          void disable() {
              _enable = 0;
          }
          void enable(unsigned channel) {
              _width  = 1;
              _enable = (1<<31) | (channel & 0xffff);
          }
      public:
          Reg               _enable;
          Reg               _delay;
          Reg               _width;
          uint32_t          _rsvd[61];
      };

      class EvrV2CoreTriggers {
      public:
          EvrV2CoreTriggers() {}
      public:
          EvrV2Channel&  channel(unsigned i) { return _channels[i]; }
          EvrV2Trig&     trigger(unsigned i) { return _triggers[i]; }
      private:
          EvrV2Channel      _channels[16];
          EvrV2Trig         _triggers[16];
      };
  };
};

#endif
