#define __STDC_FORMAT_MACROS 1

#include "hsd/RegProxy.hh"
#include "hsd/DataDriver.h"
#include <unistd.h>
#include <stdio.h>
#include <inttypes.h>
#include <semaphore.h>

typedef volatile uint32_t vuint32_t;

static int _fd = -1;
static const char* _base = 0;

using namespace Pds::HSD;

void RegProxy::initialize(int fd, const void* base)
{
  _fd = fd;
  _base = reinterpret_cast<const char*>(base);
}

RegProxy& RegProxy::operator=(const unsigned r)
{
  dmaWriteRegister(_fd, (char*)this-_base, r);
  return *this;
}

RegProxy& RegProxy::operator|=(const unsigned r)
{
  uint32_t v;
  dmaReadRegister(_fd, (char*)this-_base, &v);
  v |= r;
  dmaWriteRegister(_fd, (char*)this-_base, v);
  return *this;
}

RegProxy& RegProxy::operator&=(const unsigned r)
{
  uint32_t v;
  dmaReadRegister(_fd, (char*)this-_base, &v);
  v &= r;
  dmaWriteRegister(_fd, (char*)this-_base, v);
  return *this;
}

RegProxy::operator unsigned() const 
{
  uint32_t r;
  dmaReadRegister(_fd, (char*)this-_base, &r);
  return r;
}
