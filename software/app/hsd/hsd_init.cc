
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <arpa/inet.h>
#include <poll.h>
#include <signal.h>
#include <new>

#include "hsd/Module.hh"
#include "hsd/Globals.hh"
#include "hsd/AxiVersion.hh"
#include "hsd/TprCore.hh"
#include "hsd/RingBuffer.hh"

#include <string>

extern int optind;

using namespace Pds::HSD;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <dev> [default: /dev/datadev_0]\n");
  printf("\t-C <initialize clock synthesizer>\n");
  printf("\t-R <reset timing frame counters>\n");
  printf("\t-X <reset gtx timing receiver>\n");
  printf("\t-P <reverse gtx rx polarity>\n");
  printf("\t-0 <dump raw timing receive buffer>\n");
  printf("\t-1 <dump timing message buffer>\n");
  printf("\t-2 <configure for LCLSII>\n");
  //  printf("Options: -a <IP addr (dotted notation)> : Use network <IP>\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char* endptr;

  const char* dev="/dev/datadev_0";
  int c;
  bool lUsage = false;
  bool lSetupClkSynth = false;
  bool lReset = false;
  bool lResetRx = false;
  bool lPolarity = false;
  bool lRing0 = false;
  bool lRing1 = false;
  bool lTrain = false;
  bool lTrainNoReset = false;
  TimingType timing=LCLS;

  const char* fWrite=0;
#if 0
  bool lSetPhase = false;
  unsigned delay_int=0, delay_frac=0;
#endif
  unsigned trainRefDelay = 0;

  while ( (c=getopt( argc, argv, "CRXP0123D:d:htT:W:")) != EOF ) {
    switch(c) {
    case 'C':
      lSetupClkSynth = true;
      break;
    case 'P':
      lPolarity = true;
      break;
    case 'R':
      lReset = true;
      break;
    case 'X':
      lResetRx = true;
      break;
    case '0':
      lRing0 = true;
      break;
    case '1':
      lRing1 = true;
      break;
    case '2':
      timing = LCLSII;
      break;
    case '3':
      timing = EXTERNAL;
      break;
    case 'd':
      dev = optarg;
      break;
    case 't':
      lTrainNoReset = true;
      break;
    case 'T':
      lTrain = true;
      trainRefDelay = strtoul(optarg,&endptr,0);
      break;
    case 'D':
#if 0      
      lSetPhase = true;
      delay_int  = strtoul(optarg,&endptr,0);
      if (endptr[0]) {
        delay_frac = strtoul(endptr+1,&endptr,0);
      }
#endif
      break;
    case 'W':
      fWrite = optarg;
      break;
    case '?':
    default:
      lUsage = true;
      break;
    }
  }

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  int fd = open(dev, O_RDWR);
  if (fd<0) {
    perror("Open device failed");
    return -1;
  }

  Module* p = Module::create(fd);
  p->dumpMap();

  //p->board_status();

  //p->fmc_dump();

  if (lSetupClkSynth) {
    p->fmc_clksynth_setup(timing);
  }

  if (lPolarity) {
    p->tpr().rxPolarity(!p->tpr().rxPolarity());
  }

  if (lResetRx) {
    if (lSetupClkSynth)
      sleep(1);

    switch(timing) {
    case LCLS:
      p->tpr().setLCLS();
      break;
    case LCLSII:
      p->tpr().setLCLSII();
      break;
    default:
      return 0;
      break;
    }
    p->tpr().resetRxPll();
    usleep(10000);
    p->tpr().resetRx();
  }

  if (lReset)
    p->tpr().resetCounts();

  printf("TPR [%p]\n", &(p->tpr()));
  p->tpr().dump();

  for(unsigned i=0; i<5; i++) {
    timespec tvb;
    clock_gettime(CLOCK_REALTIME,&tvb);
    unsigned vvb = p->tpr().TxRefClks;

    usleep(10000);

    timespec tve;
    clock_gettime(CLOCK_REALTIME,&tve);
    unsigned vve = p->tpr().TxRefClks;
    
    double dt = double(tve.tv_sec-tvb.tv_sec)+1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
    printf("TxRefClk rate = %f MHz\n", 16.e-6*double(vve-vvb)/dt);
  }

  for(unsigned i=0; i<5; i++) {
    timespec tvb;
    clock_gettime(CLOCK_REALTIME,&tvb);
    unsigned vvb = p->tpr().RxRecClks;

    usleep(10000);

    timespec tve;
    clock_gettime(CLOCK_REALTIME,&tve);
    unsigned vve = p->tpr().RxRecClks;
    
    double dt = double(tve.tv_sec-tvb.tv_sec)+1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
    printf("RxRecClk rate = %f MHz\n", 16.e-6*double(vve-vvb)/dt);
  }

  if (lTrain) {
    if (lResetRx)
      sleep(1);
    p->fmc_init(timing);
    p->train_io(trainRefDelay);
  }

  if (lTrainNoReset) {
    p->train_io(trainRefDelay);
  }

  if (fWrite) {
    FILE* f = fopen(fWrite,"r");
    if (f)
      p->flash_write(f);
    else 
      perror("Failed opening prom file\n");
  }

  if (lRing0 || lRing1) {
    RingBuffer& b = *new((char*)p->reg()+(lRing0 ? 0x50000 : 0x60000)) RingBuffer;
    b.clear ();
    b.enable(true);
    usleep(100);
    b.enable(false);
    b.dump();
  }

  return 0;
}
