#include "TriggerEventManager.hh"

#include <unistd.h>

using namespace Pds::Mmhw;

void TriggerEventBuffer::start (unsigned group,
                                unsigned triggerDelay,
                                unsigned pauseThresh)
{
  status.setBit(31);
  usleep(100);
  status.clearBit(31);
  Reg& reset = *reinterpret_cast<Reg*>(&this->resetCounters);
  reset= 1;
  this->group        = group;
  this->pauseThresh  = pauseThresh;
  this->triggerDelay = triggerDelay;
  reset = 0;
  this->enable       = 3;  // b0 = enable triggers, b1 = enable axiStream
}

void TriggerEventBuffer::stop  ()
{
  this->enable       = 0;
}

