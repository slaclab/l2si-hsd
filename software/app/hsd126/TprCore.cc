#include "TprCore.hh"

#include <stdio.h>
#include <unistd.h>

using namespace Pds::HSD;

bool TprCore::rxPolarity() const {
  uint32_t v = CSR;
  return v&(1<<2);
}

void TprCore::rxPolarity(bool p) {
  volatile uint32_t v = CSR;
  v = p ? (v|(1<<2)) : (v&~(1<<2));
  CSR = v;
  usleep(10);
  CSR = v|(1<<3);
  usleep(10);
  CSR = v&~(1<<3);
}

void TprCore::resetRx() {
  volatile uint32_t v = CSR;
  CSR = (v|(1<<3));
  usleep(10);
  CSR = (v&~(1<<3));
}

void TprCore::resetRxPll() {
  volatile uint32_t v = CSR;
  CSR = (v|(1<<7));
  usleep(10);
  CSR = (v&~(1<<7));
}

void TprCore::resetCounts() {
  volatile uint32_t v = CSR;
  CSR = (v|1);
  usleep(10);
  CSR = (v&~1);
}

void TprCore::setLCLS() {
  volatile uint32_t v = CSR;
  v &= ~(1<<4);
  CSR = v;
  printf("setLCLS: v %08x  CSR %08x\n", v, unsigned(CSR));
}

void TprCore::setLCLSII() {
  volatile uint32_t v = CSR;
  CSR = v | (1<<4);
}

void TprCore::dump() const {
#define PR(r) printf("%s: %08x\n", #r, unsigned(r))
  PR(SOFcounts);
  PR(EOFcounts);
  PR(Msgcounts);
  PR(CRCerrors);
  PR(RxRecClks);
  PR(RxRstDone);
  PR(RxDecErrs);
  PR(RxDspErrs);
  { unsigned v = CSR;
    printf("CSR      : %08x", v); 
    printf(" %s", v&(1<<1) ? "LinkUp":"LinkDn");
    if (v&(1<<2)) printf(" RXPOL");
    printf(" %s", v&(1<<4) ? "LCLSII":"LCLS");
    if (v&(1<<5)) printf(" LinkDnL");
    printf("\n");
    //  Acknowledge linkDownL bit
    const_cast<TprCore*>(this)->CSR = v & ~(1<<5);
  }
  PR(TxRefClks);
  printf("BypDone  : %04x\n", (BypassCnts>> 0)&0xffff);
  printf("BypResets: %04x\n", (BypassCnts>>16)&0xffff);
  PR(Version);
}
