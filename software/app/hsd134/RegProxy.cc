#define __STDC_FORMAT_MACROS 1

#include "RegProxy.hh"
#include "Reg.hh"

#include <semaphore.h>
#include <unistd.h>
#include <stdio.h>
#include <inttypes.h>

static uint64_t _base = 0;
static Pds::Mmhw::Reg* _csr = 0;
static sem_t _sem;

using namespace Pds::Mmhw;

void RegProxy::initialize(void* base, void* csr)
{
    printf("RegProxy::initialize base %p  csr %p\n",base,csr);
  sem_init(&_sem, 0, 1);
  _base = reinterpret_cast<uint64_t>(base);
  _csr  = reinterpret_cast<Pds::Mmhw::Reg*>(csr);
  //  Test if proxy exists
  { 
    const unsigned t = 0xdeadbeef;
    _csr[2] = t;
    volatile unsigned v = _csr[2];
    if (v != t) {
       printf("RegProxy non-existent\n");
      _csr = 0;
    }
  }
}

RegProxy& RegProxy::operator=(const unsigned r)
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
      printf("RegProxy tmo (%x) writing 0x%x to %" PRIx64 "\n", 
             tmo, r, reinterpret_cast<uint64_t>(this)-_base);
    }
  } while ( (_csr[1]&1)==0 );

  sem_post(&_sem);

  return *this;
}

RegProxy::operator unsigned() const 
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
      printf("RegProxy tmo (%x) read from %" PRIx64 "\n", 
             tmo, reinterpret_cast<uint64_t>(this)-_base);
    }
  } while ( (_csr[1]&1)==0 );
  
  unsigned r = _csr[3];

  sem_post(&_sem);

  return r;
}
