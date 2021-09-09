#ifndef HSD_Mmcm_hh
#define HSD_Mmcm_hh

#include "Globals.hh"
#include "Reg.hh"

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
      Pds::Mmhw::Reg rsvd0[6];
      Pds::Mmhw::Reg ClkOut5_1;
      Pds::Mmhw::Reg ClkOut5_2;
      Pds::Mmhw::Reg ClkOut0_1;
      Pds::Mmhw::Reg ClkOut0_2;
      Pds::Mmhw::Reg ClkOut1_1;
      Pds::Mmhw::Reg ClkOut1_2;
      Pds::Mmhw::Reg ClkOut2_1;
      Pds::Mmhw::Reg ClkOut2_2;
      Pds::Mmhw::Reg ClkOut3_1;
      Pds::Mmhw::Reg ClkOut3_2;
      Pds::Mmhw::Reg ClkOut4_1;
      Pds::Mmhw::Reg ClkOut4_2;
      Pds::Mmhw::Reg ClkOut6_1;
      Pds::Mmhw::Reg ClkOut6_2;
      Pds::Mmhw::Reg ClkFbOut_1;
      Pds::Mmhw::Reg ClkFbOut_2;
      Pds::Mmhw::Reg DivClk;
      Pds::Mmhw::Reg rsvd1;
      Pds::Mmhw::Reg Lock_1;
      Pds::Mmhw::Reg Lock_2;
      Pds::Mmhw::Reg Lock_3;
      Pds::Mmhw::Reg rsvd1B[12];
      Pds::Mmhw::Reg PowerU;
      Pds::Mmhw::Reg rsvd3[38];
      Pds::Mmhw::Reg Filt_1;
      Pds::Mmhw::Reg Filt_2;
      Pds::Mmhw::Reg rsvd4[0x200-0x50];
    };
  };
};

#endif
