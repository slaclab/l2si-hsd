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
        void setGate(unsigned begin, unsigned length) { _begin = (begin&0xfffff); _length = (length&0xfffff); }
        void setFull(unsigned rows, unsigned events) { _full = (rows&0xffff) | (events<<16); }
        void getFree(unsigned& rows, unsigned& events) {
          unsigned v = _free;
          rows   = v&0xffff;
          events = v>>16;
        }
        void dump() const {
            printf("begin 0x%x  length 0x%x  full 0x%x  free 0x%x\n",
                   unsigned(_begin), unsigned(_length), unsigned(_full), unsigned(_free));
        }
      public:
        RegProxy _begin;
        RegProxy _length; // and prescale
        RegProxy _full; 
        RegProxy _free;
      } _base  [8];

      RegProxy _rsvd2[28];

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
        void dump() const {
          printf("params 0x%x 0x%x 0x%x 0x%x\n",
                 unsigned(parms[0].v), unsigned(parms[1].v), unsigned(parms[2].v), unsigned(parms[3].v));
        }
      } _stream[8];

    private:
      RegProxy _rsvd3[(0x1000-0x900)>>2];
    };
  };
};

#endif
