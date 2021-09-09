#ifndef HSD_QABase_hh
#define HSD_QABase_hh

#include "Globals.hh"
#include "Reg.hh"

namespace Pds {
  namespace HSD {

    class QABase {
    public:
      void init();
      void setChannels(unsigned);
      enum Interleave { Q_NONE, Q_ABCD };
      void setMode    (Interleave);
      void setupDaq (unsigned partition);
      void setupLCLS(unsigned rate);
      void setupLCLSII(unsigned rate);
      void setTrigShift(unsigned shift);
      void enableDmaTest(bool);
      void start();
      void stop ();
      void resetCounts();
      void resetClock (bool);
      void resetDma   ();
      void resetFb    ();
      void resetFbPLL ();
      void setLocalId (unsigned v);
      void dump() const;
    public:
      void start   (unsigned fmc);
      void stop    (unsigned fmc);
      void setupDaq(unsigned partition, unsigned fmc);
      unsigned running() const;
    public:
      Pds::Mmhw::Reg irqEnable;
      Pds::Mmhw::Reg irqStatus;
      Pds::Mmhw::Reg partitionAddr;
      Pds::Mmhw::Reg dmaFullThr;
      Pds::Mmhw::Reg csr; 
      //   CSR
      // [ 0:0]  count reset
      // [ 1:1]  dma size histogram enable (unused)
      // [ 2:2]  dma test pattern enable
      // [ 3:3]  adc sync reset
      // [ 4:4]  dma reset
      // [ 5:5]  fb phy reset
      // [ 6:6]  fb pll reset
      // [ 8:15] trigger bit mask shift
      // [31:30] acqEnable per FMC
      Pds::Mmhw::Reg acqSelect;
      //   AcqSelect
      // [12: 0]  rateSel  :   [7:0] eventCode
      // [31:13]  destSel
      Pds::Mmhw::Reg control;
      //   Control
      // [7:0] channel enable mask
      // [8:8] interleave
      // [19:16] partition FMC 0
      // [23:20] partition FMC 1
      // [24]  inhibit
      Pds::Mmhw::Reg samples;       //  Must be a multiple of 16 [v1 only]
      Pds::Mmhw::Reg prescale;      //  Sample prescaler [v1 only]
      //   Prescale
      //   Values are mapped as follows:
      //  Value    Rate Divisor    Nominal Rate
      //   [0..1]       1           1250 MHz
      //     2          2            625 MHz
      //   [3..5]       5            250 MHz
      //   [6..7]      10            125 MHz
      //   [8..15]     20             62.5 MHz
      //  [16..23]     30             41.7 MHz
      //  [24..31]     40             31.3 MHz
      //  [32..39]     50             25 MHz
      //  [40..47]     60             20.8 MHz
      //  [48..55]     70             17.9 MHz
      //  [56..63]     80             15.6 MHz
      //  Delay (bits 6:31) [units of TimingRef clk]
      Pds::Mmhw::Reg offset;        //  Not implemented
      Pds::Mmhw::Reg countAcquire;
      Pds::Mmhw::Reg countEnable;
      Pds::Mmhw::Reg countInhibit;
      Pds::Mmhw::Reg countRead;
      Pds::Mmhw::Reg countStart;
      Pds::Mmhw::Reg countQueue;
      //
      Pds::Mmhw::Reg cacheSel;
      Pds::Mmhw::Reg cacheState;
      Pds::Mmhw::Reg cacheAddr;

      Pds::Mmhw::Reg msgDelay;
      Pds::Mmhw::Reg headerCnt;

      Pds::Mmhw::Reg rsvd_84[5];

      Pds::Mmhw::Reg localId;
      Pds::Mmhw::Reg upstreamId;
      Pds::Mmhw::Reg dnstreamId[4];
      //
      //      Pds::Mmhw::Reg status;
      //      Pds::Mmhw::Reg statusCount[32];
    };
  };
};

#endif
