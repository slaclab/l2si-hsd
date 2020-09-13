#ifndef HSD_FexCfg_hh
#define HSD_FexCfg_hh

#include "hsd/RegProxy.hh"
#include <stdint.h>

namespace Pds {
  namespace HSD {
    class FexCfg {
    public:
      RegProxy _streams;
      RegProxy _rsvd[3];

      class StreamBase {
      public:
        StreamBase() {}
      public:
        void setGate(unsigned begin, unsigned length) { _gate = (begin&0xffff) | (length<<16); }
        void setFull(unsigned rows, unsigned events) { _full = (rows&0xffff) | (events<<16); }
        void getFree(unsigned& rows, unsigned& events) {
          unsigned v = _free;
          rows   = v&0xffff;
          events = v>>16;
        }
      public:
        RegProxy _prescale;
        RegProxy _gate;
        RegProxy _full; 
        RegProxy _free;
      } _base  [4];

      RegProxy _rsvd2[44];

      class Stream {
      public:
        Stream() {}
      public:
        RegProxy rsvd [4];
        class Parm {
        public:
          RegProxy v;
          RegProxy rsvd;
        } parms[30];
      } _stream[4];

    private:
      RegProxy _rsvd3[(0x1000-0x500)>>2];
    };
  };
};

#endif
