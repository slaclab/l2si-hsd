#include "hsd/QABase.hh"

#include <unistd.h>
#include <stdio.h>

using namespace Pds::HSD;

void QABase::init()
{
  unsigned v = csr;
  v &= ~(1<<30);
  csr = v | (1<<28);
  usleep(10);
  csr = v & ~(1<<28);
  usleep(10000);  // Wait for an evrBus strobe to clear the reset
}

void QABase::start()
{
  unsigned v = control;
  v &= ~(1<<24);  // remove inhibit
  control = v;

  v = csr;
  csr = v | (1<<30);

  irqEnable = 1;
}

void QABase::stop()
{
  unsigned v = csr;
  csr = v & ~(1<<30) & ~(1<<1);
}

void QABase::resetCounts()
{
  unsigned v = csr;
  csr = v | (1<<0);
  usleep(10);
  csr = v & ~(1<<0);
}

void QABase::enableDmaTest(bool enable)
{
  unsigned v = csr;
  if (enable)
    v |= (1<<2);
  else
    v &= ~(1<<2);
  csr = v;
}

void QABase::resetClock(bool r)
{
  unsigned v = csr;
  if (r) 
    v |= (1<<3);
  else
    v &= ~(1<<3);
  csr = v;

  if (!r) {
    // check for locked bit
    for(unsigned i=0; i<5; i++) {
      if (clockLocked()) {
        printf("clock locked\n");
        return;
      }
      usleep(10000);
    }
    printf("clock not locked\n");
  }
}

void QABase::resetDma()
{
  unsigned v = csr;
  v |= (1<<28);
  csr = v;
  usleep(10);
  v &= ~(1<<28);
  csr = v;
  usleep(10000);  // Wait for an evrBus strobe to clear the reset
}

void QABase::resetFb()
{
  unsigned v = csr;
  v |= (1<<5);
  csr = v;
  usleep(10);
  v &= ~(1<<5);
  csr = v;
  usleep(10);
}

void QABase::resetFbPLL()
{
  unsigned v = csr;
  v |= (1<<6);
  csr = v;
  usleep(10);
  v &= ~(1<<6);
  csr = v;
  usleep(10);
}

bool QABase::clockLocked() const
{
  unsigned v = adcSync;
  return v&(1<<31);
}

void QABase::dump() const
{
#define PR(r) printf("%9.9s: %08x\n",#r, unsigned(r))

  PR(irqEnable);
  PR(irqStatus);
  PR(partitionAddr);
  PR(dmaFullThr);
  PR(csr);
  PR(acqSelect);
  PR(control);
  PR(samples);
  PR(prescale);
  PR(offset);
  PR(countAcquire);
  PR(countEnable);
  PR(countInhibit);
  PR(dmaFullQ);
  PR(adcSync);

#undef PR
}
