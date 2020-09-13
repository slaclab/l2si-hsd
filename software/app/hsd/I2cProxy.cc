#define __STDC_FORMAT_MACROS 1

#include "hsd/I2cProxy.hh"
#include "hsd/RegProxy.hh"
#include <unistd.h>
#include <stdio.h>
#include <inttypes.h>
#include <semaphore.h>

typedef volatile uint32_t vuint32_t;

using namespace Pds::HSD;

static uint64_t _base = 0;
static RegProxy* _csr = 0;
static sem_t _sem;

void I2cProxy::initialize(void* base, void* csr)
{
  _base = reinterpret_cast<uint64_t>(base);
  _csr  = reinterpret_cast<RegProxy*>(csr);
  sem_init(&_sem,0,1);

  //  Test if proxy exists
  { 
    const unsigned t = 0xdeadbeef;
    _csr[2] = t;
    volatile unsigned v = _csr[2];
    if (v != t)
      _csr = 0;
  }
}

I2cProxy& I2cProxy::operator=(const unsigned r)
{
  if (!_csr) {
    _reserved = r;
    return *this;
  }

  sem_wait(&_sem);

  //  launch transaction
  _csr[3] = r;
  _csr[2] = reinterpret_cast<uint64_t>(this)-_base;
  _csr[0] = 0;

  //  wait until transaction is complete
  unsigned tmo=0;
  unsigned tmo_mask = 0x3;
  do { 
    usleep(1000);
    if ((++tmo&tmo_mask) ==  tmo_mask) {
      tmo_mask = (tmo_mask<<1) | 1;
      printf("I2cProxy tmo (%x) writing 0x%x to %" PRIx64 "\n", 
             tmo, r, reinterpret_cast<uint64_t>(this)-_base);
    }
  } while ( (_csr[1]&1)==0 );

  sem_post(&_sem);

  return *this;
}

I2cProxy::operator unsigned() const 
{
  if (!_csr) {
    return _reserved;
  }

  sem_wait(&_sem);

  //  launch transaction
  _csr[2] = reinterpret_cast<uint64_t>(this)-_base;
  _csr[0] = 1;

  //  wait until transaction is complete
  unsigned tmo=0;
  unsigned tmo_mask = 0x3;
  do { 
    usleep(1000);
    if ((++tmo&tmo_mask) == tmo_mask) {
      tmo_mask = (tmo_mask<<1) | 1;
      printf("I2cProxy tmo (%x) read from %" PRIx64 "\n", 
             tmo, reinterpret_cast<uint64_t>(this)-_base);
    }
  } while ( (_csr[1]&1)==0 );
  
  unsigned r = _csr[3];

  sem_post(&_sem);

  return r;
}
