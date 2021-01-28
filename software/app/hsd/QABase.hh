#ifndef HSD_QABase_hh
#define HSD_QABase_hh

#include "hsd/RegProxy.hh"

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class QABase {
    public:
      void init();
      void enableDmaTest(bool);
      void start();
      void stop ();
      void resetCounts();
      void resetClock (bool);
      void resetDma   ();
      void resetFb    ();
      void resetFbPLL ();
      bool clockLocked() const;
      void dump() const;
    public:
      RegProxy irqEnable;
      RegProxy irqStatus;
      RegProxy partitionAddr;
      RegProxy dmaFullThr;
      RegProxy csr; 
      //   CSR
      // [ 0:0]  count reset
      // [ 1:1]  dma size histogram enable
      // [ 2:2]  dma test pattern enable
      // [ 3:3]  adc sync reset
      // [ 4:4]  dma reset
      // [ 5:5]  fb phy reset
      // [ 8:15] trigger bit mask shift
      // [31:31] acqEnable
      RegProxy acqSelect;
      //   AcqSelect
      // [12: 0]  rateSel  :   [7:0] eventCode
      // [31:13]  destSel
      RegProxy control;
      //   Control
      // [7:0] channel enable mask
      // [8:8] interleave
      // [19:16] partition
      RegProxy samples;       //  Must be a multiple of 16
      RegProxy prescale;
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
      RegProxy offset;        //  Delay (bits 19:0) [TimingRef clks]
      RegProxy countAcquire;
      RegProxy countEnable;
      RegProxy countInhibit;
      RegProxy dmaFullQ;
      RegProxy adcSync;
      RegProxy reserved_60;
      //
      RegProxy cacheSel;
      RegProxy cacheState;
      RegProxy cacheAddr;
      //
      //      RegProxy status;
      //      RegProxy statusCount[32];
    };
  };
};

#endif
