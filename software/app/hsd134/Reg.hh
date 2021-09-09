#ifndef Kcu_Reg_hh
#define Kcu_Reg_hh

#include <stdint.h>

namespace Pds {
    namespace Mmhw {
        class Reg {
        public:
            Reg& operator=(const unsigned);
            operator unsigned() const;
        public:
            void setBit  (unsigned);
            void clearBit(unsigned);
        public:
            static void set(unsigned fd);
            static void verbose(bool);
        private:
            uint32_t _reserved;
        };
    };
};

#endif
