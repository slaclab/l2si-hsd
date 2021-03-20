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
      } _stream[8];

    private:
      RegProxy _rsvd3[(0x1000-0x900)>>2];
    };
  };
};

#endif
