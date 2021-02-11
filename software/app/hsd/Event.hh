#ifndef HSD_DATA_HH
#define HSD_DATA_HH

#include <stdint.h>
#include <stdio.h>

namespace Pds {
    namespace HSD {

        class StreamHeader {
        public:
            StreamHeader() {}
        public:
            const uint16_t*     data() const { return reinterpret_cast<const uint16_t*>(this+1); }

            unsigned num_samples() const { return _word[0]&0x3fffffff; }
            unsigned stream_id  () const { return (_word[1]>>24)&0xff; }
            unsigned samples () const { return num_samples(); } // number of samples
            bool     unlocked() const { return (_word[0]>>30)&1; }        // data serial link unlocked
            bool     overflow() const { return (_word[0]>>31)&1; }        // overflow of memory buffer
            unsigned strmtype() const { return (_word[1]>>24)&0xff; } // type of stream {raw, thr, ...}
            unsigned boffs   () const { return (_word[1]>>0)&0xff; }  // padding at start
            unsigned eoffs   () const { return (_word[1]>>8)&0xff; }  // padding at end
            unsigned buffer  () const { return _word[1]>>16; }        // 16 front-end buffers (like FEE)
            // (only need 4 bits but using 16)
            unsigned toffs   () const { return (_word[2]>> 0)&0xffff; } // phase between sample clock and timing clock (1.25GHz)
            unsigned l1tag   () const { return (_word[2]>>16)&0x1f; }   // trigger tag word
            // wrong if this value is not fixed
            unsigned baddr   () const { return _word[3]&0xffff; }     // begin address in circular buffer
            unsigned eaddr   () const { return _word[3]>>16; }        // end address in circular buffer
            void     dump    () const
            {
                printf("StreamHeader dump\n");
                printf("  ");
                for(unsigned i=0; i<4; i++)
                    printf("%08x%c", _word[i], i<3 ? '.' : '\n');
                printf("  id [%u]  size [%04u]  boffs [%u]  eoffs [%u]  buff [%u]  toffs[%04u]  baddr [%04x]  eaddr [%04x]\n",
                       stream_id(), samples(), boffs(), eoffs(), buffer(), toffs(), baddr(), eaddr());
            }
        private:
            uint32_t _word[4];
        };

        class StreamIterator;

        class EventHeader {
        public:
            EventHeader() {}
        public:
            StreamIterator streams() const;

            //unsigned eventType () const { return service(); }
            uint64_t timeStamp () const { return ((uint64_t)_tshigh << 32) | _tslow; }
            //unsigned samples   () const { return _info[0]&0xfffff; }
            unsigned streamMask() const { return (_info[0]>>20)&0xff; }
            unsigned sync      () const { return _info[1]&0x7; }

            void dump() const
            {
                printf("EventHeader dump\n");
                uint32_t* word = (uint32_t*) this;
                for(unsigned i=0; i<8; i++)
                    printf("[%d] %08x ", i, word[i]);//, i<7 ? '.' : '\n');
                printf("time [%u.%09u]  sync [%u]\n",
                       _tshigh, _tslow,
                       sync());
                printf("####@ 0x%x 0x%x 0x%x %llu\n", _info[0], _info[1], streamMask(), (unsigned long long) timeStamp());
            }
        private:
            uint32_t _reserved[2];
            // TimeStamp
            uint32_t _tslow;
            uint32_t _tshigh;
            //
            uint32_t _reserved2[2];
            //
            uint32_t _info[2];
        };

        class StreamIterator {
        public:
            StreamIterator(const EventHeader& event) : _event(event) {}
        public:
            const StreamHeader* first() { 
                _remaining = _event.streamMask(); 
                if (!_remaining) return 0;
                _remaining &= _remaining-1;
                _current   = reinterpret_cast<const StreamHeader*>(&_event+1);
                return _current;
            }
            const StreamHeader* next () {
                if (!_remaining) return 0;
                _remaining &= _remaining-1;
                const uint16_t* q = _current->data();
                _current   = reinterpret_cast<const StreamHeader*>(q + _current->samples());
                return _current;
            }
        private:
            const EventHeader&  _event;
            const StreamHeader* _current;
            unsigned            _remaining;
        };

        StreamIterator EventHeader::streams() const { return StreamIterator(*this); }
    };
};

#endif
