
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

#include "Module134.hh"

#include <string>

extern int optind;

using namespace Pds::HSD;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <dev> [default: /dev/datadev_0]\n");
  //  printf("Options: -a <IP addr (dotted notation)> : Use network <IP>\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char* endptr;

  const char* dev="/dev/datadev_0";
  int c;
  bool lUsage = false;

  while ( (c=getopt( argc, argv, "d:h")) != EOF ) {
    switch(c) {
    case 'd':
      dev = optarg;
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

  Module134* m = Module134::create(fd);
  m->dumpMap();
  m->board_status();
  printf("--timing--\n");
  m->setup_timing();

  std::string adccal;
  m->setup_jesd(false,adccal,adccal);

  unsigned busId = strtoul(dev+strlen(dev)-2,NULL,16);
  m->set_local_id(busId);

#if 0
  //  Name the remote partner on the timing link
  { unsigned upaddr = m->remote_id();
    std::string paddr = Psdaq::AppUtils::parse_paddr(upaddr);
    printf("paddr [0x%x] [%s]\n", upaddr, paddr.c_str());
  }
#endif

  return 0;
}
