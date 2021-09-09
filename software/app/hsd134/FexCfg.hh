#ifndef HSD_FexCfg_hh
#define HSD_FexCfg_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {
    class FexCfg {
    public:
      void disable();
    public:
      Pds::Mmhw::Reg _streams;
      Pds::Mmhw::Reg _oflow;
      Pds::Mmhw::Reg _flowstatus;
      Pds::Mmhw::Reg _flowidxs;

      class StreamBase {
      public:
        StreamBase() {}
      public:
        void setGate(unsigned begin, unsigned length) { 
          _reg[0] = begin;
          _reg[1] = (_reg[1] & ~0xfffff) | (length & 0xfffff);
        }
        void setFull(unsigned rows, unsigned events) { 
          _reg[2] = (rows&0xffff) | (events<<16); 
        }
        void setPrescale(unsigned prescale) {
          _reg[1] = (_reg[1] & 0xfffff) | (prescale<<20);
        }
        void getFree(unsigned& rows, unsigned& events, unsigned& oflow) {
#if 1   // machine check exception
          unsigned v = _reg[3];
#else
          unsigned v = 0;
#endif 
          rows   = (v>> 0)&0xffff;
          events = (v>>16)&0x1f;
          oflow  = (v>>24)&0xff;
        }
        void dump() const;
      public:
        Pds::Mmhw::Reg _reg[4];
      } _base  [4];

      Pds::Mmhw::Reg _rsvd_50[0xb0>>2];

      class Stream {
      public:
        Stream() {}
      public:
        Pds::Mmhw::Reg rsvd [4];
        class Parm {
        public:
          Pds::Mmhw::Reg v;
          Pds::Mmhw::Reg rsvd;
        } parms[30];
      } _stream[4];
    };
  };
};

#endif
