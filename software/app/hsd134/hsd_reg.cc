//
//

#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <vector>

#include "DmaDriver.h"

extern int optind;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options:\n");
  printf("\t-d <dev>        : device file name\n");
  printf("\t-a <addr>       : read from address\n");
  printf("\t-a <addr,value> : write value to address\n");
  printf("\t-A <addr,addr>  : test write to addr range\n");
}

int main(int argc, char** argv) {
  extern char* optarg;
  const char* dev = "/dev/datadev_0";
  std::vector<unsigned> rdaddr;
  std::vector<unsigned> wraddr;
  std::vector<unsigned> wrval;

  int c;
  bool lUsage = false;
  char* endptr;
  while ( (c=getopt( argc, argv, "a:A:d:h")) != EOF ) {
    switch(c) {
    case 'd':
      dev = optarg;
      break;
    case 'a':
        { unsigned addr = strtoul(optarg,&endptr,0); 
          if (*endptr==',') {
              unsigned val = strtoul(endptr+1,NULL,0);
              wraddr.push_back(addr);
              wrval .push_back(val);
          }
          else {
              rdaddr.push_back(addr);
          }
        }
        break;
    case 'A':
        { unsigned begin = strtoul(optarg,&endptr,0); 
          if (*endptr==',') {
              unsigned end = strtoul(endptr+1,NULL,0);
              for(unsigned addr=begin; addr<end; addr+=4) {
                  wraddr.push_back(addr);
                  wrval .push_back(addr);
                  rdaddr.push_back(addr);
              }
          }
        } break;
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

  for(unsigned i=0; i<rdaddr.size(); i++) {
      unsigned val;
      dmaReadRegister(fd, rdaddr[i], &val);
      printf("Read [%08x] %08x\n",rdaddr[i],val);
  }

  for(unsigned i=0; i<wraddr.size(); i++) {
      unsigned val = wrval[i];
      dmaWriteRegister(fd, wraddr[i], val);
      printf("Wrot [%08x] %08x\n",wraddr[i],val);
  }

  for(unsigned i=0; i<rdaddr.size(); i++) {
      unsigned val;
      dmaReadRegister(fd, rdaddr[i], &val);
      printf("Read [%08x] %08x\n",rdaddr[i],val);
  }

  return 0;
}
