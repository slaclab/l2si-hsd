#include "FexCfg.hh"
#include <stdio.h>

using namespace Pds::HSD;

void FexCfg::disable()
{
  _streams = 0;
}

void FexCfg::StreamBase::dump() const {
    printf("  reg: 0x%x  0x%x  0x%x  0x%x\n",
           unsigned(_reg[0]),
           unsigned(_reg[1]),
           unsigned(_reg[2]),
           unsigned(_reg[3]));
}
