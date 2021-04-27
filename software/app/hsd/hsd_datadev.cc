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

#include <map>
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
  printf("\t-d <dev>    : device file (default /dev/datadev_0)\n");
  printf("\t-I          : acquire interleaved data\n");
  printf("\t-L <samples>: samples to acquire\n");
  printf("\t-T <lo,hi>  : sparsification range\n");
}

static Module* reg=0;

const std::vector<uint16_t> _decompress(const uint16_t* data, unsigned length, uint16_t filler)
{
  std::vector<uint16_t> a(length);
  for(unsigned j=0, i=0; j<length; i++) {
    if (data[i]&0x8000)
      for(unsigned k=0; k<(data[i]&0x7fff) && j<length; k++)
        a[j++] = filler;
    else
      a[j++] = data[i]&0x3fff;
  }
  return a;
}

void sigHandler( int signal ) {
  ::exit(signal);
}

int main(int argc, char** argv) {
  extern char* optarg;
  const char* dev = "/dev/datadev_0";
  int c;
  bool lUsage = false;
  bool lInterleave = false;
  bool lDecompress = false;
  unsigned length  = 40;  
  unsigned nevents = 10;
  //  sparsify values between lo_threshold and hi_threshold
  FexParams q;
  q.lo_threshold=0;
  q.hi_threshold=0;
  q.rows_before =2;
  q.rows_after  =2;
  char* endptr;
  
  while ( (c=getopt( argc, argv, "d:n:hDIL:T:")) != EOF ) {
    switch(c) {
    case 'd':
      dev = optarg;
      break;
    case 'n':
      nevents = strtoul(optarg,NULL,0);
      break;
    case 'D':
      lDecompress = true;
      break;
    case 'I':
      lInterleave = true;
      break;
    case 'L':
      length = strtoul(optarg,NULL,0);
      break;
    case 'T':
      q.lo_threshold = strtoul(optarg  ,&endptr,0);
      q.hi_threshold = strtoul(endptr+1,&endptr,0);
      printf("Read lo/hi 0x%x/0x%x\n",q.lo_threshold,q.hi_threshold);
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
  p->stop();

  // "Rows" of data 
  // 1 row = 8 samples four channel mode or 
  //        32 samples one channel mode)
  
  if (!lInterleave) {
    length = 32*(length/32);
    //  Four channel readout
    p->sample_init(length, 1, 0, -1, 0xf);
  }
  else {
    length = 8*(length/8);
    //  One channel readout (interleaved)
    unsigned channel = 0; // input channel
    p->sample_init(length, 1, 0, channel, 0x1f, q);
  }

  //  Setup trigger
  unsigned eventcode = 40;
  p->trig_lcls( eventcode );

  const unsigned maxSize = 1<<24;
  uint32_t* data = new uint32_t[maxSize];
  unsigned flags;
  unsigned error;
  unsigned dest;
  ssize_t  nb;

  //  Enable
  p->start();

  std::map<unsigned,unsigned> sizeMap;

  for(unsigned ievt = 0; ievt < nevents; ) {
      if ((nb = dmaRead(fd, data, maxSize, &flags, &error, &dest))>0) {
          sizeMap[nb]++;
          printf("Read %zu bytes\n",nb);
          ievt++;
          const EventHeader* eh = reinterpret_cast<const EventHeader*>(data);
          eh->dump();
          StreamIterator it = eh->streams();
          for(const StreamHeader* sh = it.first(); sh; sh=it.next()) {
              sh->dump();
              const uint16_t* samples = sh->data();
              for(unsigned i=0; i<sh->samples(); i++)
                  printf(" %04x", samples[i]);
              printf("\n");
              //  sanity checks
              //  No sparsification in other streams
              if (sh->stream_id()<4) {
                for(unsigned i=0; i<sh->samples(); i++)
                  if (samples[i]&0x8000) {
                    printf("Found skip samples in unsparsified stream\n");
                    abort();
                  }
              }
              //  Check series of 4 skip-samples
              else {
                for(unsigned i=0; i<sh->samples(); i++)
                  if (samples[i]&0x8000) {
                    for(unsigned k=0; k<3; k++)
                      if (samples[++i]!=0x8000) {
                        printf("Found non-zero skip sample after 1st skip");
                        abort();
                      }
                  }
              }
              if (sh->stream_id()>=4 && lDecompress) {
                //  decompress
                printf("  --decompressed\n");
                const std::vector<uint16_t> s = _decompress(samples,length,(q.lo_threshold+q.hi_threshold)/2);
                for(unsigned i=0; i<s.size(); i++)
                  printf(" %04x", s[i]);
                printf("\n");
              }
          }
      }
  }

  p->stop();

  delete[] data;

  for(std::map<unsigned,unsigned>::iterator it=sizeMap.begin(); it!=sizeMap.end(); it++) {
    printf("sizeMap[%u] : %u\n", it->first, it->second);
  }

  return 0;
}
