#include "hsd/Module.hh"

#include "hsd/AxiVersion.h"
#include "hsd/TprCore.hh"
#include "hsd/RxDesc.hh"
#include "hsd/ClkSynth.hh"
#include "hsd/Mmcm.hh"
#include "hsd/DmaCore.hh"
#include "hsd/PhyCore.hh"
#include "hsd/Pgp2bAxi.hh"
#include "hsd/RingBuffer.hh"
#include "hsd/I2cSwitch.hh"
#include "hsd/LocalCpld.hh"
#include "hsd/FmcSpi.hh"
#include "hsd/QABase.hh"
#include "hsd/Adt7411.hh"
#include "hsd/Tps2481.hh"
#include "hsd/AdcCore.hh"
#include "hsd/AdcSync.hh"
#include "hsd/FmcCore.hh"
#include "hsd/FexCfg.hh"
#include "hsd/FlashController.hh"
#include "hsd/I2cProxy.hh"
#include "hsd/PhaseMsmt.hh"
#include "hsd/TriggerEventManager.hh"
#include "hsd/Xvc.hh"
#include "hsd/DmaDriver.h"

#include <string>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <poll.h>
#include <inttypes.h>

#define DISABLE_READOUT_B

typedef volatile uint32_t vuint32_t;

namespace Pds {
  namespace HSD {
    class Module::PrivateData {
    public:
      //  Initialize busses
      void init(unsigned fmc);

      //  Initialize clock tree and IO training
      void fmc_init(unsigned fmc, TimingType);

      int  train_io(unsigned);

      void enable_test_pattern(unsigned fmc,TestPattern);
      void disable_test_pattern(unsigned fmc);
      void enable_cal (unsigned fmc);
      void disable_cal(unsigned fmc);
      void setAdcMux(bool     interleave,
                     unsigned channel,
                     unsigned fmc);

      void setRxAlignTarget(unsigned);
      void setRxResetLength(unsigned);
      void dumpRxAlign     () const;
      void dumpPgp         () const;
      //
      //  Low level API
      //
    public:
      uint32_t rsvd_to_0x080000[(0x80000)/4];

      FlashController      flash;
      uint32_t rsvd_to_0x090000[(0x10000-sizeof(FlashController))/4];

      // XvcSrc
      Jtag jtag;
      uint32_t rsvd_to_0x0A0000[(0x10000-sizeof(jtag))/4];

      // I2C
      I2cSwitch i2c_sw_control;  // 0xA0000
      ClkSynth  clksynth;        // 0xA0400
      LocalCpld local_cpld;      // 0xA0800
      Adt7411   vtmon1;          // 0xA0C00
      Adt7411   vtmon2;          // 0xA1000
      Adt7411   vtmon3;          // 0xA1400
      Tps2481   imona;           // 0xA1800
      Tps2481   imonb;           // 0xA1C00
      Adt7411   vtmona;          // 0xA2000
      FmcSpi    fmc_spi;         // 0xA2400
      uint32_t rsvd_to_0x0A8000[(0x05c00-sizeof(fmc_spi))/4];
      uint32_t  regProxy[(0x08000)/4];
      //uint32_t rsvd_to_0x0B0000[(0x08000-sizeof(regProxy))/4];

      // GTH
      uint32_t gthAlign[10];     // 0xB0000
      uint32_t rsvd_to_0xB0100  [54];
      uint32_t gthAlignTarget;
      uint32_t gthAlignLast;
      uint32_t rsvd_to_0x0B0200[62];
      uint32_t rsvd_to_0x0C0000[(0x0FE00)/4];

      // TIM
      Pds::HSD::TprCore  tpr;     // 0xC0000
      uint32_t rsvd_to_0x0D0000  [(0x010000-sizeof(Pds::HSD::TprCore))/4];

      RingBuffer         ring0;   // 0xD0000
      uint32_t rsvd_to_0x0E0000  [(0x10000-sizeof(RingBuffer))/4];

      RingBuffer         ring1;   // 0xE0000
      uint32_t rsvd_to_0x0F0000  [(0x10000-sizeof(RingBuffer))/4];
      uint32_t rsvd_to_0x100000[(0x010000)/4];

      // App
      QABase   base;             // 0x100000
      uint32_t rsvd_to_0x80800  [(0x800-sizeof(QABase))/4];

      Mmcm     mmcm;             // 0x100800
      FmcCore  fmca_core;        // 0x101000
      AdcCore  adca_core;        // 0x101400
      FmcCore  fmcb_core;        // 0x101800
      AdcCore  adcb_core;        // 0x101C00
      AdcSync  adc_sync;         // 0x102000
      uint32_t rsvd_to_0x102800  [(0x800-sizeof(AdcSync))/4];

      PhaseMsmt           phase; // 0x102800
      uint32_t rsvd_to_0x108000  [(0x5000)/4];

      FexCfg   fex_chan[4];      // 0x108000
      uint32_t rsvd_to_0x110000  [(0x4000)/4];
      TriggerEventManager tem;   // 0x110000;
    };
  };
};

using namespace Pds::HSD;

Module* Module::create(int fd, unsigned fmc)
{
  Module* m = new Module;
  m->p = 0;
  m->_fd = fd;
  m->_fmc = fmc;

  uint8_t dmaMask[DMA_MASK_SIZE];
  dmaInitMaskBytes(dmaMask);
  dmaAddMaskBytes(dmaMask,fmc<<8);
  dmaSetMaskBytes(fd,dmaMask);

  Pds::HSD::RegProxy::initialize(m->_fd);
  Pds::HSD::I2cProxy::initialize(m->p, m->p->regProxy);

  return m;
}

Module* Module::create(int fd, unsigned fmc, TimingType timing)
{
  Module* m = create(fd,fmc);

  //
  //  Verify clock synthesizer is setup
  //
  if (timing != EXTERNAL) {
    timespec tvb;
    clock_gettime(CLOCK_REALTIME,&tvb);
    unsigned vvb = m->tpr().TxRefClks;

    usleep(10000);

    timespec tve;
    clock_gettime(CLOCK_REALTIME,&tve);
    unsigned vve = m->tpr().TxRefClks;
    
    double dt = double(tve.tv_sec-tvb.tv_sec)+1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
    double txclkr = 16.e-6*double(vve-vvb)/dt;
    printf("TxRefClk: %f MHz\n", txclkr);

    static const double TXCLKR_MIN[] = { 118., 185. };
    static const double TXCLKR_MAX[] = { 120., 187. };
    if (txclkr < TXCLKR_MIN[timing] ||
        txclkr > TXCLKR_MAX[timing]) {
      m->fmc_clksynth_setup(timing);

      usleep(100000);
      if (timing==LCLS)
        m->tpr().setLCLS();
      else
        m->tpr().setLCLSII();
      m->tpr().resetRxPll();
      usleep(10000);
      m->tpr().resetRx();

      usleep(100000);
      m->fmc_init(timing);
      m->train_io(0);
    }
  }

  return m;
}

Module::~Module()
{
}

int Module::read(void* data, unsigned data_size)
{
  size_t nb = dmaRead(_fd,data,data_size,NULL,NULL,NULL);
  return nb;
}

enum 
{
        FMC12X_INTERNAL_CLK = 0,                                                /*!< FMC12x_init() configure the FMC12x for internal clock operations */
        FMC12X_EXTERNAL_CLK = 1,                                                /*!< FMC12x_init() configure the FMC12x for external clock operations */
        FMC12X_EXTERNAL_REF = 2,                                                /*!< FMC12x_init() configure the FMC12x for external reference operations */

        FMC12X_VCXO_TYPE_2500MHZ = 0,                                   /*!< FMC12x_init() Vco on the card is 2.5GHz */
        FMC12X_VCXO_TYPE_2200MHZ = 1,                                   /*!< FMC12x_init() Vco on the card is 2.2GHz */
        FMC12X_VCXO_TYPE_2000MHZ = 2,                                   /*!< FMC12x_init() Vco on the card is 2.0GHz */
};

enum 
{
        CLOCKTREE_CLKSRC_EXTERNAL = 0,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for external clock operations */
        CLOCKTREE_CLKSRC_INTERNAL = 1,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for internal clock operations */
        CLOCKTREE_CLKSRC_EXTREF   = 2,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for external reference operations */

        CLOCKTREE_VCXO_TYPE_2500MHZ = 0,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.5GHz */
        CLOCKTREE_VCXO_TYPE_2200MHZ = 1,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.2GHz */
        CLOCKTREE_VCXO_TYPE_2000MHZ = 2,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.0GHz */
        CLOCKTREE_VCXO_TYPE_1600MHZ = 3,                                                /*!< FMC12x_clocktree_init() Vco on the card is 1.6 GHZ */
        CLOCKTREE_VCXO_TYPE_BUILDIN = 4,                                                /*!< FMC12x_clocktree_init() Vco on the card is the AD9517 build in VCO */
        CLOCKTREE_VCXO_TYPE_2400MHZ = 5                                                 /*!< FMC12x_clocktree_init() Vco on the card is 2.4GHz */
};

enum 
{       // clock sources
        CLKSRC_EXTERNAL_CLK = 0,                                                /*!< FMC12x_cpld_init() external clock. */
        CLKSRC_INTERNAL_CLK_EXTERNAL_REF = 3,                   /*!< FMC12x_cpld_init() internal clock / external reference. */
        CLKSRC_INTERNAL_CLK_INTERNAL_REF = 6,                   /*!< FMC12x_cpld_init() internal clock / internal reference. */

        // sync sources
        SYNCSRC_EXTERNAL_TRIGGER = 0,                                   /*!< FMC12x_cpld_init() external trigger. */
        SYNCSRC_HOST = 1,                                                               /*!< FMC12x_cpld_init() software trigger. */
        SYNCSRC_CLOCK_TREE = 2,                                                 /*!< FMC12x_cpld_init() signal from the clock tree. */
        SYNCSRC_NO_SYNC = 3,                                                    /*!< FMC12x_cpld_init() no synchronization. */

        // FAN enable bits
        FAN0_ENABLED = (0<<4),                                                  /*!< FMC12x_cpld_init() FAN 0 is enabled */
        FAN1_ENABLED = (0<<5),                                                  /*!< FMC12x_cpld_init() FAN 1 is enabled */
        FAN2_ENABLED = (0<<6),                                                  /*!< FMC12x_cpld_init() FAN 2 is enabled */
        FAN3_ENABLED = (0<<7),                                                  /*!< FMC12x_cpld_init() FAN 3 is enabled */
        FAN0_DISABLED = (1<<4),                                                 /*!< FMC12x_cpld_init() FAN 0 is disabled */
        FAN1_DISABLED = (1<<5),                                                 /*!< FMC12x_cpld_init() FAN 1 is disabled */
        FAN2_DISABLED = (1<<6),                                                 /*!< FMC12x_cpld_init() FAN 2 is disabled */
        FAN3_DISABLED = (1<<7),                                                 /*!< FMC12x_cpld_init() FAN 3 is disabled */

        // LVTTL bus direction (HDMI connector)
        DIR0_INPUT      = (0<<0),                                                       /*!< FMC12x_cpld_init() DIR 0 is input */
        DIR1_INPUT      = (0<<1),                                                       /*!< FMC12x_cpld_init() DIR 1 is input */
        DIR2_INPUT      = (0<<2),                                                       /*!< FMC12x_cpld_init() DIR 2 is input */
        DIR3_INPUT      = (0<<3),                                                       /*!< FMC12x_cpld_init() DIR 3 is input */
        DIR0_OUTPUT     = (1<<0),                                                       /*!< FMC12x_cpld_init() DIR 0 is output */
        DIR1_OUTPUT     = (1<<1),                                                       /*!< FMC12x_cpld_init() DIR 1 is output */
        DIR2_OUTPUT     = (1<<2),                                                       /*!< FMC12x_cpld_init() DIR 2 is output */
        DIR3_OUTPUT     = (1<<3),                                                       /*!< FMC12x_cpld_init() DIR 3 is output */
};

void Module::PrivateData::init(unsigned fmc)
{
  i2c_sw_control.select((fmc==0) ? I2cSwitch::PrimaryFmc : I2cSwitch::SecondaryFmc);
  fmc_spi.initSPI();
}

void Module::PrivateData::fmc_init(unsigned fmc, TimingType timing)
{
// if(FMC12x_init(AddrSipFMC12xBridge, AddrSipFMC12xClkSpi, AddrSipFMC12xAdcSpi, AddrSipFMC12xCpldSpi, AddrSipFMC12xAdcPhy, 
//                modeClock, cardType, GA, typeVco, carrierKC705)!=FMC12X_ERR_OK) {

#if 1
  const uint32_t clockmode = FMC12X_EXTERNAL_REF;
#else
  const uint32_t clockmode = FMC12X_INTERNAL_CLK;
#endif

  //  uint32_t clksrc_cpld;
  uint32_t clksrc_clktree;
  uint32_t vcotype = 0; // default 2500 MHz

  if(clockmode==FMC12X_INTERNAL_CLK) {
    //    clksrc_cpld    = CLKSRC_INTERNAL_CLK_INTERNAL_REF;
    clksrc_clktree = CLOCKTREE_CLKSRC_INTERNAL;
  }
  else if(clockmode==FMC12X_EXTERNAL_REF) {
    //    clksrc_cpld    = CLKSRC_INTERNAL_CLK_EXTERNAL_REF;
    clksrc_clktree = CLOCKTREE_CLKSRC_EXTREF;
  }
  else {
    //    clksrc_cpld    = CLKSRC_EXTERNAL_CLK;
    clksrc_clktree = CLOCKTREE_CLKSRC_EXTERNAL;
  }

  const char cfmc = (fmc==0) ? 'A':'B';
  FmcCore& fmc_core = (fmc==0) ? fmca_core : fmcb_core;
  if (!fmc_core.present()) {
    printf("FMC card %c not present\n",cfmc);
    printf("FMC init failed!\n");
    return;
  }

  printf("FMC card %c initializing\n",cfmc);
  i2c_sw_control.select((fmc==0) ? I2cSwitch::PrimaryFmc : I2cSwitch::SecondaryFmc); 
  if (fmc_spi.cpld_init())
    printf("cpld_init failed!\n");
  if (fmc_spi.clocktree_init(clksrc_clktree, vcotype, timing))
    printf("clocktree_init failed!\n");
}

//
//  IO Training
//
int Module::PrivateData::train_io(unsigned ref_delay)
{
  if (!fmca_core.present()) {
    printf("FMC card A not present\n");
    printf("IO training failed!\n");
    return -1;
  }

  //  bool fmcb_present = fmcb_core.present();
  bool fmcb_present = false;

  i2c_sw_control.select(I2cSwitch::PrimaryFmc);
  if (fmc_spi.adc_enable_test(Flash11)) 
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_enable_test(Flash11)) 
      return -1;
  }

  //  adcb_core training is driven by adca_core
  adca_core.init_training(0x08);
  if (fmcb_present)
    adcb_core.init_training(ref_delay);

  adca_core.start_training();

  adca_core.dump_training();
  
  if (fmcb_present)
    adcb_core.dump_training();

  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  if (fmc_spi.adc_disable_test())
    return -1;
  if (fmc_spi.adc_enable_test(Flash11))
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_disable_test())
      return -1;
    if (fmc_spi.adc_enable_test(Flash11))
      return -1;
  }

  adca_core.loop_checking();
  if (fmcb_present)
    adcb_core.loop_checking();

  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  if (fmc_spi.adc_disable_test())
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_disable_test())
      return -1;
  }

  return 0;
}

void Module::PrivateData::enable_test_pattern(unsigned fmc, TestPattern p)
{
  if (p < 8) {
    i2c_sw_control.select(fmc);
    fmc_spi.adc_enable_test(p);
  }
  else
    base.enableDmaTest(true);
}

void Module::PrivateData::disable_test_pattern(unsigned fmc)
{
  i2c_sw_control.select(fmc);
  fmc_spi.adc_disable_test();
  base.enableDmaTest(false);
}

void Module::PrivateData::enable_cal(unsigned fmc)
{
  i2c_sw_control.select(fmc);
  fmc_spi.adc_enable_cal();
  FmcCore& fmc_core = (fmc==0) ? fmca_core : fmcb_core;
  fmc_core.cal_enable();
}

void Module::PrivateData::disable_cal(unsigned fmc)
{
  i2c_sw_control.select(fmc);
  FmcCore& fmc_core = (fmc==0) ? fmca_core : fmcb_core;
  fmc_core.cal_disable();
  fmc_spi.adc_disable_cal();
}

void Module::PrivateData::setRxAlignTarget(unsigned t)
{
  unsigned v = gthAlignTarget;
  v &= ~0x3f;
  v |= (t&0x3f);
  gthAlignTarget = v;
}

void Module::PrivateData::setRxResetLength(unsigned len)
{
  unsigned v = gthAlignTarget;
  v &= ~0xf0000;
  v |= (len&0xf)<<16;
  gthAlignTarget = v;
}
 
void Module::PrivateData::dumpRxAlign     () const
{
  printf("\nTarget: %u\tRstLen: %u\tLast: %u\n",
         gthAlignTarget&0x7f,
         (gthAlignTarget>>16)&0xf, 
         gthAlignLast&0x7f);
  for(unsigned i=0; i<128; i++) {
    printf(" %04x",(gthAlign[i/2] >> (16*(i&1)))&0xffff);
    if ((i%10)==9) printf("\n");
  }
  printf("\n");
}

void Module::PrivateData::dumpPgp     () const
{
  printf("\tnone\n");
  return;
#if 0
  //  Need to reset after clocks come back
  //  const_cast<Module::PrivateData*>(this)->pgp_fmc2 = 0x9;
  //  const_cast<Module::PrivateData*>(this)->base.resetDma();
  
  // for(unsigned i=0; i<4; i++) {
  //   printf("Lane %d [%p]:\n",i, &pgp[i]);
  //   pgp[i].dump();
  // }
  {
#define LPRINT(title,field) {                     \
      printf("\t%20.20s :",title);                \
      for(unsigned i=0; i<4; i++)                 \
        printf(" %11x",pgp[i].field);             \
      printf("\n"); }
    
#define LPRBF(title,field,shift,mask) {                 \
      printf("\t%20.20s :",title);                      \
      for(unsigned i=0; i<4; i++)                       \
        printf(" %11x",(pgp[i].field>>shift)&mask);     \
      printf("\n"); }
    
#define LPRVC(title,field) {                      \
      printf("\t%20.20s :",title);                \
      for(unsigned i=0; i<4; i++)                 \
        printf(" %2x %2x %2x %2x",                \
               pgp[i].field##0,                   \
             pgp[i].field##1,                     \
             pgp[i].field##2,                     \
             pgp[i].field##3 );                   \
    printf("\n"); }

#define LPRFRQ(title,field) {                           \
      printf("\t%20.20s :",title);                      \
      for(unsigned i=0; i<4; i++)                       \
        printf(" %11.4f",double(pgp[i].field)*1.e-6);   \
      printf("\n"); }
    
    LPRINT("loopback",_loopback);
    LPRINT("txUserData",_txUserData);
    LPRBF ("rxPhyReady",_status,0,1);
    LPRBF ("txPhyReady",_status,1,1);
    LPRBF ("localLinkReady",_status,2,1);
    LPRBF ("remoteLinkReady",_status,3,1);
    LPRBF ("transmitReady",_status,4,1);
    LPRBF ("rxPolarity",_status,8,3);
    LPRBF ("remotePause",_status,12,0xf);
    LPRBF ("localPause",_status,16,0xf);
    LPRBF ("remoteOvfl",_status,20,0xf);
    LPRBF ("localOvfl",_status,24,0xf);
    LPRINT("remoteData",_remoteUserData);
    LPRINT("cellErrors",_cellErrCount);
    LPRINT("linkDown",_linkDownCount);
    LPRINT("linkErrors",_linkErrCount);
    LPRVC ("remoteOvflVC",_remoteOvfVc);
    LPRINT("framesRxErr",_rxFrameErrs);
    LPRINT("framesRx",_rxFrames);
    LPRVC ("localOvflVC",_localOvfVc);
    LPRINT("framesTxErr",_txFrameErrs);
    LPRINT("framesTx",_txFrames);
    LPRFRQ("rxClkFreq",_rxClkFreq);
    LPRFRQ("txClkFreq",_txClkFreq);
    LPRINT("lastTxOp",_lastTxOpcode);
    LPRINT("lastRxOp",_lastRxOpcode);
    LPRINT("nTxOps",_txOpcodes);
    LPRINT("nRxOps",_rxOpcodes);

#undef LPRINT
#undef LPRBF
#undef LPRVC
#undef LPRFRQ
  }

  printf("pgp_fmc: %08x:%08x\n",
         pgp_fmc1, pgp_fmc2);
  printf("\n");

  // for(unsigned i=0; i<4; i++)
  //    const_cast<Module::PrivateData*>(this)->pgp[i]._countReset = 1;
  // usleep(10);
  // for(unsigned i=0; i<4; i++)
  //    const_cast<Module::PrivateData*>(this)->pgp[i]._countReset = 0;

  //   These registers are not yet writable
#if 0
  for(unsigned i=0; i<4; i++)
    const_cast<Module::PrivateData*>(this)->pgp[i]._loopback = 2;
  for(unsigned i=0; i<4; i++)
    const_cast<Module::PrivateData*>(this)->pgp[i]._rxReset = 1;
  usleep(10);
  for(unsigned i=0; i<4; i++)
    const_cast<Module::PrivateData*>(this)->pgp[i]._rxReset = 0;
#endif
#endif
}

void Module::dumpBase() const
{
  p->base.dump();
}

void Module::dumpStatus() const
{
  p->tem.dump(0);
}

void Module::PrivateData::setAdcMux(bool     interleave,
                                    unsigned channel,
                                    unsigned fmc)
{
  i2c_sw_control.select(fmc);
  fmc_spi.setAdcMux(interleave, channel);
}

void Module::init() { p->init(_fmc); p->base.init(); }

unsigned Module::ncards() const { 
  unsigned n=0;
  if (p->fmca_core.present()) n++;
  if (p->fmcb_core.present()) n++;
  return n;
}

void Module::fmc_init(TimingType timing) { p->fmc_init(_fmc,timing); }

void Module::fmc_dump() {
  FmcCore& fmc_core = (_fmc==0) ? p->fmca_core : p->fmcb_core;
  if (fmc_core.present())
    for(unsigned i=0; i<16; i++) {
      fmc_core.selectClock(i);
      usleep(100000);
      printf("Clock [%i]: rate %f MHz\n", i, fmc_core.clockRate()*1.e-6);
    }
}

void Module::fmc_clksynth_setup(TimingType timing)
{
  p->i2c_sw_control.select(I2cSwitch::LocalBus);  // ClkSynth is on local bus
  p->clksynth.setup(timing);
  p->clksynth.dump ();
}

static uint64_t _fd_value(const AxiVersion& vsn)
{
  uint64_t v = 0;
  for(int i=7; i>=0; i--) {
    v <<= 8;
    v |= vsn.fdValue[i];
  }
  return v;
}

static uint64_t _device_dna(const AxiVersion& vsn)
{
  uint64_t v = 0;
  for(int i=7; i>=0; i--) {
    v <<= 8;
    v |= vsn.dnaValue[i];
  }
  return v;
}

uint64_t Module::device_dna() const { return _device_dna(version()); }

void Module::board_status()
{
  AxiVersion vsn = version();
  printf("Dna: %" PRIx64 "  Serial: %" PRIx64 "\n",
         _device_dna(vsn),
         _fd_value(vsn));

  p->i2c_sw_control.select(I2cSwitch::LocalBus);
  p->i2c_sw_control.dump();
  
  printf("Local CPLD revision: 0x%x\n", p->local_cpld.revision());
  printf("Local CPLD GAaddr  : 0x%x\n", p->local_cpld.GAaddr  ());
  p->local_cpld.GAaddr(0);

  printf("vtmon1 mfg:dev %x:%x\n", p->vtmon1.manufacturerId(), p->vtmon1.deviceId());
  printf("vtmon2 mfg:dev %x:%x\n", p->vtmon2.manufacturerId(), p->vtmon2.deviceId());
  printf("vtmon3 mfg:dev %x:%x\n", p->vtmon3.manufacturerId(), p->vtmon3.deviceId());

  p->vtmon1.dump();
  p->vtmon2.dump();
  p->vtmon3.dump();

  p->imona.dump();
  p->imonb.dump();

  printf("FMC A [%p]: %s present power %s\n",
         &p->fmca_core,
         p->fmca_core.present() ? "":"not",
         p->fmca_core.powerGood() ? "up":"down");

#ifndef DISABLE_READOUT_B
  printf("FMC B [%p]: %s present power %s\n",
         &p->fmcb_core,
         p->fmcb_core.present() ? "":"not",
         p->fmcb_core.powerGood() ? "up":"down");
#endif

  p->i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  p->i2c_sw_control.dump();

  printf("vtmona mfg:dev %x:%x\n", p->vtmona.manufacturerId(), p->vtmona.deviceId());

#ifndef DISABLE_READOUT_B
  p->i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
  p->i2c_sw_control.dump();

  printf("vtmonb mfg:dev %x:%x\n", p->vtmona.manufacturerId(), p->vtmona.deviceId());
#endif
}

void Module::flash_write(FILE* f)
{
  p->flash.write(f);
}

int  Module::train_io(unsigned v) { return p->train_io(v); }

void Module::enable_test_pattern(TestPattern t) { p->enable_test_pattern(_fmc,t); }

void Module::disable_test_pattern() { p->disable_test_pattern(_fmc); }

void Module::enable_cal () { p->enable_cal(_fmc); }

void Module::disable_cal() { p->disable_cal(_fmc); }

AxiVersion Module::version() const 
{
  AxiVersion vsn;
  axiVersionGet(_fd, &vsn);
  return vsn;
}
Pds::HSD::TprCore&    Module::tpr    () { return p->tpr; }
Pds::HSD::Jtag&       Module::jtag   () { return p->jtag; }
Pds::HSD::PhaseMsmt&  Module::phasemsmt() { return p->phase; }

void Module::setRxAlignTarget(unsigned v) { p->setRxAlignTarget(v); }
void Module::setRxResetLength(unsigned v) { p->setRxResetLength(v); }
void Module::dumpRxAlign     () const { p->dumpRxAlign(); }
void Module::dumpPgp         () const { p->dumpPgp(); }

void Module::sample_init(unsigned length, 
                         unsigned delay,
                         unsigned prescale,
                         int      onechannel_input,   // integer
                         unsigned streams) // bitmask
{
  //  p->base.init();  // this will interrupt the other fmc, but I think OK during configure

  unsigned nrows = (onechannel_input >= 0) ? length/32 : length/8;

  p->fex_chan[_fmc]._streams = streams;
  for(unsigned i=0; i<8; i++)
    if (streams & (1<<i)) {
      p->fex_chan[_fmc]._base[i].setGate(delay,nrows);
      if (i<4)
        p->fex_chan[_fmc]._stream[i].parms[0].v = i;
    }

  p->setAdcMux(onechannel_input>=0, onechannel_input, _fmc);

  //  flush out all the old
  { printf("flushing\n");
    unsigned nflush=0;
    uint32_t* data = new uint32_t[1<<20];
    // pollfd pfd;
    // pfd.fd = _fd;
    // pfd.events = POLLIN;
    //    while(poll(&pfd,1,0)>0) { 
    while(dmaRead(_fd, data, 1<<22, NULL, NULL, NULL)>0) {
      nflush++;
    }
    delete[] data;
    printf("done flushing [%u]\n",nflush);
  }
    
  p->base.resetCounts();
}

void Module::trig_lcls  (unsigned eventcode)
{
  //  p->base.setupLCLS(eventcode);
  p->tem.trig_lcls(eventcode,_fmc);
}

void Module::sync()
{
  p->i2c_sw_control.select(I2cSwitch::PrimaryFmc);
  p->fmc_spi.applySync();
}

void Module::start()
{
  p->base.start();
  p->tem.start(_fmc);
}

void Module::stop()
{
  p->tem.stop(_fmc);
  p->base.stop();
}

unsigned Module::get_offset(unsigned channel)
{
  p->i2c_sw_control.select(channel&0x4);
  return p->fmc_spi.get_offset(channel&0x3);
}

unsigned Module::get_gain(unsigned channel)
{
  p->i2c_sw_control.select(channel&0x4);
  return p->fmc_spi.get_gain(channel&0x3);
}

void Module::set_offset(unsigned channel, unsigned value)
{
  p->i2c_sw_control.select(channel&0x4);
  p->fmc_spi.set_offset(channel&0x3,value);
}

void Module::set_gain(unsigned channel, unsigned value)
{
  p->i2c_sw_control.select(channel&0x4);
  p->fmc_spi.set_gain(channel&0x3,value);
}

void* Module::reg() { return (void*)p; }

FexCfg* Module::fex() { return &p->fex_chan[_fmc]; }

void Module::dumpMap() const 
{
#define LOC(a) (char*)a - base
  char* base = (char*)p;
  printf("&flash    0x%08lx [0x00080000]\n", LOC(&p->flash));
  printf("&i2c      0x%08lx [0x000a0000]\n", LOC(&p->i2c_sw_control));
  printf("&i2cproxy 0x%08lx [0x000a8000]\n", LOC(&p->regProxy[0]));
  printf("&gth      0x%08lx [0x000b0000]\n", LOC(&p->gthAlign[0]));
  printf("&tpr      0x%08lx [0x000c0000]\n", LOC(&p->tpr));
  printf("&ring0    0x%08lx [0x000d0000]\n", LOC(&p->ring0));
  printf("&ring1    0x%08lx [0x000e0000]\n", LOC(&p->ring1));
  printf("&qabase   0x%08lx [0x00100000]\n", LOC(&p->base));
  printf("&fexchan  0x%08lx [0x00108000]\n", LOC(&p->fex_chan[0]));
  printf("&tem      0x%08lx [0x00110000]\n", LOC(&p->tem));
}
