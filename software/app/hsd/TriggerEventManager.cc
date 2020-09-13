#include "hsd/TriggerEventManager.hh"

#include <unistd.h>
#include <stdio.h>

using namespace Pds::HSD;

void TriggerEventManager::trig_lcls(unsigned eventcode)
{
  unsigned rdsel = (eventcode&0xff ) | (2<<11) | (2<<29);
  for(unsigned i=0; i<2; i++) {
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

void TriggerEventManager::start()
{
  for(unsigned i=0; i<2; i++)
    buffer[i].enable = 1;
}

void TriggerEventManager::stop()
{
  for(unsigned i=0; i<2; i++)
    buffer[i].enable = 0;
}

void TriggerEventManager::dump() const
{
  printf("ch[0].count   %08x\n",unsigned(evr.ch[0].count));
  printf("bu[0].enable  %08x\n",unsigned(buffer[0].enable));
  printf("bu[0].fifocsr %08x\n",unsigned(buffer[0].fifocsr));
  printf("bu[0].count   %08x\n",unsigned(buffer[0].count));
}
