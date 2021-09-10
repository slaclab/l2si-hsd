#include "Module134.hh"

#include "AxiVersion.h"
#include "ModuleBase.hh"
#include "I2c134.hh"
#include "Mmcm.hh"
#include "ChipAdcCore.hh"
#include "Jesd204b.hh"
#include "Fmc134Ctrl.hh"
//#include "FlashController.hh"
#include "OptFmc.hh"

#include "TriggerEventManager2.hh"
#include "Xvc.hh"
#include "Reg.hh"
#include "DmaDriver.h"

using Pds::Mmhw::Reg;
using Pds::Mmhw::RingBuffer;
using Pds::Mmhw::TriggerEventManager2;
using Pds::Mmhw::TriggerEventBuffer;

#include <string>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <poll.h>
#include <semaphore.h>
#include <cstdlib>

using std::string;

namespace Pds {
  namespace HSD {

    class Module134::PrivateData {
    public:
      //
      //  Low level API
      //
      //  Core registers
      ModuleBase  base                ; // 0
      //  App registers
      ChipAdcCore chip[2]             ; // 0x80000, 0x82000
        //      TriggerEventManager tem         ; // 0x84000
        //      uint32_t    rsvd_88000[(0x4000-sizeof(tem))>>2];
      uint32_t    rsvd_84000[0x4000>>2];
      Fmc134Ctrl  fmc_ctrl            ; // 0x88000
      uint32_t    rsvd_88800[(0x800-sizeof(fmc_ctrl))>>2];
      Mmcm        mmcm                ; // 0x88800
      uint32_t    rsvd_90000[(0x7800-sizeof(mmcm))>>2];
      Reg         pgp_reg  [0x8000>>2]; // 0x90000
      Reg         opt_fmc  [0x1000>>2]; // 0x98000
      Reg         qsfp0_i2c[0x1000>>2]; // 0x99000
      Reg         qsfp1_i2c[0x1000>>2]; // 0x9A000
      Reg         surf_jesd0[0x800>>2]; // 0x9B000
      Reg         surf_jesd1[0x800>>2]; // 0x9B800
      uint32_t    rsvd_9C000[0x4000>>2];
      TriggerEventManager2 tem         ; // 0xA0000
      uint32_t    rsvd_tem[2*sizeof(TriggerEventBuffer)>>2];
    };
  };
};

using namespace Pds::HSD;

Module134::Module134() 
{
  sem_init(&_sem_i2c,0,1);
}

Module134* Module134::create(int fd)
{
  // void* ptr = mmap(0, sizeof(Module134::PrivateData), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  // if (ptr == MAP_FAILED) {
  //   perror("Failed to map");
  //   return 0;
  // }

  // printf("Module134 mapped at %p with size %zx\n", ptr, sizeof(Module134::PrivateData));

  Module134* m = new Module134;
  //  m->p = reinterpret_cast<Module134::PrivateData*>(ptr);
  m->p = 0;
  m->_fd = fd;

  uint8_t dmaMask[DMA_MASK_SIZE];
  dmaInitMaskBytes(dmaMask);
  dmaAddMaskBytes(dmaMask,0<<8); // Chip 0
  dmaAddMaskBytes(dmaMask,1<<8); // Chip 1
  dmaSetMaskBytes(fd,dmaMask);

  Pds::Mmhw::Reg::set(fd);
  Pds::Mmhw::RegProxy::initialize(m->p, m->p->base.regProxy);

  return m;
}

void Module134::setup_timing()
{
  //
  //  Verify clock synthesizer is setup
  //  Necessary for timing and dual firefly channel pgp
  //
  {
    TprCore& tpr = p->base.tpr;
    tpr.dump();
    double txclkr = tpr.txRefClockRate();
    printf("TxRefClk: %f MHz\n", txclkr);

    static const double TXCLKR_MIN = 118.;
    static const double TXCLKR_MAX = 120.;
    if (txclkr < TXCLKR_MIN ||
        txclkr > TXCLKR_MAX) {
      i2c_lock(I2cSwitch::LocalBus);  // ClkSynth is on local bus
      i2c().clksynth.setup(LCLS);
      //      i2c().clksynth.setup(LCLSII);
      //      i2c().clksynth.setup(M64);
      i2c_unlock();

      usleep(100000);
      tpr.setLCLSII();
      tpr.resetRxPll();
      usleep(1000000);
      tpr.resetBB();

      ChipAdcReg& r0 = chip(0).reg;
      ChipAdcReg& r1 = chip(1).reg;
      r0.resetFb ();
      r0.resetDma();
      r1.resetDma();
      usleep(1000000);

      tpr.resetCounts();

      usleep(100000);

      tpr.resetRxPll();
      r0.resetFbPLL();
    }
  }
}

void Module134::_jesd_init(unsigned mode) 
{
  Fmc134Ctrl& ctrl = jesdctl();
  Fmc134Cpld& cpld = i2c().fmc_cpld;
  Reg* jesd0  = &p->surf_jesd0[0];
  Reg* jesd1  = &p->surf_jesd1[0];
  while(1) {
      if (!ctrl.default_init(cpld, mode)) {
          usleep(2000000);
          unsigned dvalid=0;
          for(unsigned i=0; i<8; i++) {
              dvalid |= (jesd0[0x10+i]&2) ? (0x001<<i) : 0;
              dvalid |= (jesd1[0x10+i]&2) ? (0x100<<i) : 0;
          }
          if (dvalid == 0xffff)
              break;
          printf("dvalid: 0x%x\n",dvalid);
      }
      usleep(1000);
  }            

  ctrl.dump();
}

void Module134::setup_jesd(bool lAbortOnErr,
                           std::string& adc0,
                           std::string& adc1,
                           bool         lDualCh,
                           InputChan    inputCh)
{
  i2c_lock(I2cSwitch::PrimaryFmc);
  Fmc134Cpld* cpld = &i2c().fmc_cpld;
  Fmc134Ctrl* ctrl = &p->fmc_ctrl;
  Reg* jesd0  = &p->surf_jesd0[0];
  Reg* jesd1  = &p->surf_jesd1[0];
  //  if (cpld->default_clocktree_init(Fmc134Cpld::CLOCKTREE_CLKSRC_INTERNAL))
  while (cpld->default_clocktree_init(Fmc134Cpld::CLOCKTREE_REFSRC_EXTERNAL)) {
    if (lAbortOnErr)
      abort();
    usleep(1000);
  }

  while (cpld->default_adc_init(Fmc134Cpld::FG_CAL,adc0,adc1,lDualCh,inputCh)) {
    if (lAbortOnErr)
      abort();
    usleep(1000);
  }

  cpld->dump();
  jesd0[0] = 0xff;
  jesd1[0] = 0xff;
  jesd0[4] = 0x27;
  jesd1[4] = 0x27;
  usleep(100);
  jesd0[4] = 0x23;
  jesd1[4] = 0x23;

  _jesd_init(0);

  ctrl->dump();
  i2c_unlock();
}

Module134::~Module134()
{
}

void Module134::dumpMap() const
{
  const char* cthis = reinterpret_cast<const char*>(p);
  I2c134& i2c = const_cast<Module134*>(this)->i2c();
#define OFFS(member) (reinterpret_cast<const char*>(&p->member)-cthis)
#define OFFP(pval  ) (reinterpret_cast<const char*>(&pval)-cthis)
  //  printf("FlashController: 0x%lx\n", OFFS(base.flash));
  printf("I2cSwitch      : 0x%lx\n", OFFP(i2c.i2c_sw_control));
  printf("ClkSynth       : 0x%lx\n", OFFP(i2c.clksynth));
  printf("LocalCpld      : 0x%lx\n", OFFP(i2c.local_cpld));
  //  printf("FmcSpi         : 0x%x\n", &p->fmc_spi);
  //  printf("DmaCore        : 0x%lx\n", OFFS(base.dma_core));
  printf("TprCore        : 0x%lx\n", OFFS(base.tpr));
  printf("ChipAdcCore[0] : 0x%lx\n", OFFS(chip[0]));
  printf("ChipAdcCore[1] : 0x%lx\n", OFFS(chip[1]));
  printf("Fmc134Ctrl     : 0x%lx\n", OFFS(fmc_ctrl));
  printf("mmcm           : 0x%lx\n", OFFS(mmcm));
  printf("Tem            : 0x%lx\n", OFFS(tem));
#undef OFFS
}

uint64_t Module134::device_dna() const
{
    return -1ULL;
}

void Module134::enable_test_pattern(TestPattern p)
{
  i2c_lock(I2cSwitch::PrimaryFmc);
  _jesd_init(unsigned(p));
  i2c_unlock();
}

void Module134::disable_test_pattern()
{
  i2c_lock(I2cSwitch::PrimaryFmc);
  _jesd_init(0);
  i2c_unlock();
}

// Update ID advertised on timing link

void Module134::set_local_id(unsigned bus)
{
  p->tem.xma().txId = ModuleBase::local_id(bus);
}

unsigned Module134::remote_id() const { return p->tem.xma().rxId; }

void Module134::board_status()
{
    {
      struct AxiVersion axiv;
      axiVersionGet(_fd, &axiv);

      printf("-- Core Axi Version --\n");
      printf("  firmware version  :  %x\n", axiv.firmwareVersion);
      printf("  scratch           :  %x\n", axiv.scratchPad);
      printf("  uptime count      :  %d\n", axiv.upTimeCount);
      printf("  build string      :  %s\n", axiv.buildString);
    }

  p->fmc_ctrl.dump();

  i2c_lock(I2cSwitch::LocalBus);
  { LocalCpld& v = i2c().local_cpld;
    printf("Local CPLD revision: 0x%x\n", v.revision());
    printf("Local CPLD GAaddr  : 0x%x\n", v.GAaddr  ());
    v.GAaddr(0); }

  printf("vtmon1 mfg:dev %x:%x\n", i2c().vtmon1.manufacturerId(), i2c().vtmon1.deviceId());
  printf("vtmon2 mfg:dev %x:%x\n", i2c().vtmon2.manufacturerId(), i2c().vtmon2.deviceId());
  printf("vtmon3 mfg:dev %x:%x\n", i2c().vtmon3.manufacturerId(), i2c().vtmon3.deviceId());

  i2c().vtmon1.dump();
  i2c().vtmon2.dump();
  i2c().vtmon3.dump();

  printf("imona/b\n");
  i2c().imona.dump();
  i2c().imonb.dump();
  i2c_unlock();

  i2c_lock(I2cSwitch::PrimaryFmc);
  { unsigned v;
    printf("FMC EEPROM:");
    for(unsigned i=0; i<32; i++) {
      v = i2c().eeprom[i];
      printf(" %02x", v&0xff);
    }
    printf("\n");
  }

  i2c().fmc_cpld.dump();

  i2c().fmc_cpld.enable_mon(true);
  printf("-- fmcadcmon --\n");
  FmcAdcMon(i2c().fmcadcmon.mon()).dump();

  printf("-- fmcvmon --\n");
  FmcVMon(i2c().fmcvmon.mon()).dump();
  i2c().fmc_cpld.enable_mon(false);

  i2c_unlock();
}

ChipAdcCore& Module134::chip   (unsigned ch) { return p->chip[ch]; }

void Module134::dumpRxAlign     () const { p->base.dumpRxAlign(); }

void* Module134::reg() { return (void*)p; }

TriggerEventManager2& Module134::tem() { return p->tem; }

Fmc134Ctrl& Module134::jesdctl() { return p->fmc_ctrl; }

OptFmc&     Module134::optfmc() { return *reinterpret_cast<OptFmc*>(p->opt_fmc); }

Mmcm&       Module134::mmcm() { return p->mmcm; }

TprCore&    Module134::tpr() { return p->base.tpr; }

Jesd204b& Module134::jesd(unsigned ch)
{ return *reinterpret_cast<Jesd204b*>(ch==0 ? p->surf_jesd0 : p->surf_jesd1); }

void   Module134::mon_start()
{
  i2c_lock(I2cSwitch::LocalBus);
  i2c().vtmon1.start();
  i2c().vtmon2.start();
  i2c().vtmon3.start();
  i2c().imona.start();
  i2c().imonb.start();
  i2c_unlock();
}

EnvMon Module134::mon() const
{
  i2c_lock(I2cSwitch::LocalBus);
  EnvMon v;
  Adt7411_Mon m;
  I2c134& i2c = const_cast<Module134*>(this)->i2c();
  m = i2c.vtmon1.mon();
  v.local12v = m.ain[3]*6.;
  v.edge12v  = m.ain[6]*6.;
  v.aux12v   = m.ain[7]*6.;
  m = i2c.vtmon2.mon();
  v.boardTemp = m.Tint;
  //  v.boardTemp = m.Text;
  v.local1_8v = m.ain[6];
  m = i2c.vtmon3.mon();
  v.fmc12v = m.ain[2]*6.;
  v.local2_5v = m.ain[6]*2.;
  v.local3_3v = m.ain[7]*2.;

  v.fmcPower   = i2c.imona.power_W();
  v.totalPower = i2c.imonb.power_W();
  i2c_unlock();

  return v;
}

I2c134& Module134::i2c()
{
  return p->base.i2c;
}

void Module134::i2c_lock  (I2cSwitch::Port port) const
{
  sem_wait(&_sem_i2c);
  const_cast<Module134*>(this)->i2c().i2c_sw_control.select(port);
}
void Module134::i2c_unlock() const { sem_post(&_sem_i2c); }

Pds::Mmhw::Jtag& Module134::xvc()
{
  return p->base.jtag;
}

void Module134::sample_init (unsigned length,
                             unsigned delay,
                             unsigned prescale,
                             int      onechannel_input,
                             unsigned streams,
                             const FexParams& params)
{
    sample_init(length,delay,prescale,onechannel_input,streams);

    for(unsigned _fmc=0; _fmc<2; _fmc++) {
        FexCfg&     fex = chip(_fmc).fex;
        // sparsification is in stream 3
        fex._stream[3].parms[0].v = params.lo_threshold;
        fex._stream[3].parms[1].v = params.hi_threshold;
        fex._stream[3].parms[2].v = params.rows_before;
        fex._stream[3].parms[3].v = params.rows_after ;
    }
}

void Module134::sample_init (unsigned length,
                             unsigned delay,
                             unsigned prescale,
                             int      onechannel_input,
                             unsigned streams)
{
  printf("length 0x%x  delay 0x%x  prescale 0x%x  streams 0x%x\n",
         length, delay, prescale, streams);
  
  for(unsigned _fmc=0; _fmc<2; _fmc++) {

        ChipAdcReg& reg = chip(_fmc).reg;
        FexCfg&     fex = chip(_fmc).fex;

        reg.init();
        reg.resetCounts();
        //  The above generates a reset that persists until a 360 Hz trigger strobe
        //  Need to wait until the reset is complete, else later axi-lite transactions fail.
        usleep(10000);

        unsigned nrows = length/8;

#define DBG_WRITE(r,v) { r=v; }
  
        for(unsigned i=0; i<4; i++) {
            if (streams & (1<<(4*_fmc+i))) {
                fex._base[i].setGate(delay,nrows);
                fex._base[i].setFull(1024,6);
                if (i==2)  // raw interleaved
                    fex._base[i].setPrescale(prescale-1);
                fex._base[i].dump();
                if (i<2)
                    fex._stream[i].parms[0].v = i;
            }
        }

#undef DBG_WRITE
        fex._streams = ( (streams >> (4*_fmc)) &0xf ) | (6<<8);
        reg.setChannels(1);

      printf("streams: %2u\n", fex._streams &0xf);
    }  

    //  flush out all the old
    { printf("flushing\n");
        unsigned nflush=0;
        uint32_t* data = new uint32_t[1<<20];
        while(dmaRead(_fd, data, 1<<22, NULL, NULL, NULL)>0) {
            nflush++;
        }
        delete[] data;
        printf("done flushing [%u]\n",nflush);
    }
    
}

void Module134::trig_lcls  (unsigned eventcode)
{
    tem().evr().channel(0).enable(eventcode);
    tem().evr().channel(1).enable(eventcode);
    tem().evr().trigger(0).enable(0);
    tem().evr().trigger(1).enable(0);
}

void Module134::sync       () {}

void Module134::start      ()
{
    chip(0).reg.start();
    chip(1).reg.start();
    tem().det(0).start(0,0,16);
    tem().det(1).start(0,0,16);
}

void Module134::stop       ()
{
    tem().det(0).stop();
    tem().det(1).stop();
    chip(0).reg.stop();
    chip(1).reg.stop();
}
