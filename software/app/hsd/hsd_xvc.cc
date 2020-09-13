//
//

#include <stdio.h>
#include <unistd.h>

#include "Module.hh"
#include "Xvc.hh"

using namespace Pds::HSD;

extern int optind;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options:\n");
  printf("\t-d <device>\n");
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

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  //
  //  Configure channels, event selection
  //
  printf("Using %s\n",dev);

  int fd = open(dev, O_RDWR);
  if (fd<0) {
    perror("Could not open");
    return -1;
  }

  Module* p = Module::create(fd);
  Xvc::launch( &p->jtag(), 11000, false );
  while(1)
    sleep(1);
  return 0;
}
