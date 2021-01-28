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

  return 0;
}
