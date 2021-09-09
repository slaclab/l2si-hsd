#ifndef HSD_Mmcm_hh
#define HSD_Mmcm_hh

#include <stdint.h>

#include "RegProxy.hh"

namespace Pds {
  namespace HSD {
    class Mmcm {
    public:
      void setLCLS  (unsigned delay_int, unsigned delay_frac);
      void setLCLSII(unsigned delay_int, unsigned delay_frac);
    private:
      void _setFbMult(unsigned);
      void _setClkDiv(unsigned,unsigned);
      void _setLock  (unsigned);
      void _setFilt  (unsigned);
    private:
      RegProxy rsvd0[6];
      RegProxy ClkOut5_1;
      RegProxy ClkOut5_2;
      RegProxy ClkOut0_1;
      RegProxy ClkOut0_2;
      RegProxy ClkOut1_1;
      RegProxy ClkOut1_2;
      RegProxy ClkOut2_1;
      RegProxy ClkOut2_2;
      RegProxy ClkOut3_1;
      RegProxy ClkOut3_2;
      RegProxy ClkOut4_1;
      RegProxy ClkOut4_2;
      RegProxy ClkOut6_1;
      RegProxy ClkOut6_2;
      RegProxy ClkFbOut_1;
      RegProxy ClkFbOut_2;
      RegProxy DivClk;
      RegProxy rsvd1;
      RegProxy Lock_1;
      RegProxy Lock_2;
      RegProxy Lock_3;
      RegProxy rsvd1B[12];
      RegProxy PowerU;
      RegProxy rsvd3[38];
      RegProxy Filt_1;
      RegProxy Filt_2;
      RegProxy rsvd4[0x200-0x50];
    };
  };
};

#endif
