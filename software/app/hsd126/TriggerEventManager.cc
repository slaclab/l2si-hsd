#include "TriggerEventManager.hh"

#include <unistd.h>
#include <stdio.h>

using namespace Pds::HSD;

void TriggerEventManager::trig_lcls(unsigned eventcode,
                                    unsigned chan)
{
  unsigned rdsel = (eventcode&0xff ) | (2<<11) | (2<<29);
  {
    unsigned i=chan;
    evr.ch[i].ratedestsel = rdsel;
    evr.ch[i].enable = 1;
    evr.tr[i].delay  = 1;
    evr.tr[i].width  = 1;
    evr.tr[i].enable = (1<<31) | i;
    buffer[i].enable = 0;
    buffer[i].resetCount = 1;
    buffer[i].fifocsr = (1<<31);
    usleep(10);
    buffer[i].fifocsr = 0;
    buffer[i].resetCount = 0;
  }
}

void TriggerEventManager::start(unsigned chan)
{
  buffer[chan].enable = 1;
}

void TriggerEventManager::stop(unsigned chan)
{
  buffer[chan].enable  = 0;
  buffer[chan].fifocsr = (1<<31);
}

void TriggerEventManager::dump(unsigned chan) const
{
  printf("ch.count   %08x\n",unsigned(evr.ch[chan].count));
  printf("bu.enable  %08x\n",unsigned(buffer[chan].enable));
  printf("bu.fifocsr %08x\n",unsigned(buffer[chan].fifocsr));
  printf("bu.count   %08x\n",unsigned(buffer[chan].count));
}
