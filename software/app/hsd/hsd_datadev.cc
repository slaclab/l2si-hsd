//
//

#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <semaphore.h>
#include <poll.h>
#include <signal.h>
#include <arpa/inet.h>

#include <string>
#include <vector>

#include "hsd/Module.hh"
#include "hsd/AxiVersion.hh"
#include "hsd/Event.hh"
#include "hsd/DmaDriver.h"

using namespace Pds::HSD;

extern int optind;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options:\n");
  printf("\t-d          : device file (default /dev/datadev_0)\n");
}

static Module* reg=0;

void sigHandler( int signal ) {
  ::exit(signal);
}

int main(int argc, char** argv) {
  extern char* optarg;
  const char* dev = "/dev/datadev_0";
  int c;
  bool lUsage = false;
  while ( (c=getopt( argc, argv, "d:h")) != EOF ) {
    switch(c) {
    case 'd':
      dev = optarg;
      break;
    case 'h':
      usage(argv[0]);
      exit(0);
    case '?':
    default:
      lUsage = true;
      break;
    }
  }

  if (optind < argc) {
    printf("%s: invalid argument -- %s\n",argv[0], argv[optind]);
    lUsage = true;
  }

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  int fd = open(dev, O_RDWR);
  if (fd<0) {
    perror("Could not open");
    return -1;
  }

  Module* p = reg = Module::create(fd,0);
  p->dumpMap();

  printf("BuildStamp: %s\n",p->version().buildString);

  p->dumpBase();

  p->disable_test_pattern();
  //  p->enable_test_pattern(pattern);

  p->init();

  // "Rows" of data 
  // 1 row = 8 samples four channel mode or 
  //        32 samples one channel mode)
  
  unsigned length = 40;  
  //  Four channel readout
  p->sample_init(length, 1, 0, -1, 0xf);
  //  One channel readout (interleaved)
  //  unsigned channel = 0; // input channel
  //  p->sample_init(length, 0, 0, channel, 0x10);

  //  Setup trigger
  unsigned eventcode = 40;
  p->trig_lcls( eventcode );

  //  Enable
  p->start();

  const unsigned nevents = 10;
  const unsigned maxSize = 1<<24;
  uint32_t* data = new uint32_t[maxSize];
  unsigned flags;
  unsigned error;
  unsigned dest;
  ssize_t  nb;

  for(unsigned ievt = 0; ievt < nevents; ) {
      if ((nb = dmaRead(fd, data, maxSize, &flags, &error, &dest))>0) {
          ievt++;
          const EventHeader* eh = reinterpret_cast<const EventHeader*>(data);
          eh->dump();
          StreamIterator it = eh->streams();
          for(const StreamHeader* sh = it.first(); sh; sh=it.next()) {
              sh->dump();
              const uint16_t* samples = sh->data();
              for(unsigned i=0; i<8; i++)
                  printf(" %04x", samples[i]);
              printf("\n");
          }
      }
  }

  p->stop();

  return 0;
}
