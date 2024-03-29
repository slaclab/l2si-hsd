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

#include "Histogram.hh"
#include "Module.hh"
#include "Event.hh"
#include "QABase.hh"
#include "TprCore.hh"
#include "DmaDriver.h"

using namespace Pds::HSD;

extern int optind;

static const unsigned NCHANNELS = 14;
static const unsigned NTRIGGERS = 12;
static const unsigned short port_req = 11000;
static bool lVerbose = false;

class ThreadArgs {
public:
  int fd;
  unsigned busyTime;
  sem_t sem;
  int reqfd;
  int rate;
};


class DaqStats {
public:
  DaqStats() : _values(7) {
    for(unsigned i=0; i<_values.size(); i++)
      _values[i]=0;
  }
public:
  static const char** names();
  std::vector<unsigned> values() const { return _values; }
public:
  unsigned& eventFrames () { return _values[0]; }
  unsigned& dropFrames  () { return _values[1]; }
  unsigned& repeatFrames() { return _values[2]; }
  unsigned& tagMisses   () { return _values[3]; }
  unsigned& corrupt     () { return _values[4]; }
  unsigned& anaTags     () { return _values[5]; }
  unsigned& anaErrs     () { return _values[6]; }
private:
  std::vector<unsigned> _values;
};  

const char** DaqStats::names() {
  static const char* _names[] = {"eventFrames",
                                 "dropFrames",
                                 "repeatFrames",
                                 "tagMisses",
                                 "corrupt",
                                 "anaTags",
                                 "anaErrs" };
  return _names;
}


class DmaStats {
public:
  DmaStats() : _values(4) {
    for(unsigned i=0; i<_values.size(); i++)
      _values[i]=0;
  }
  DmaStats(const QABase& o) : _values(4) {
    frameCount   () = o.countEnable;
    pauseCount   () = o.countInhibit;
  }

public:
  static const char** names();
  std::vector<unsigned> values() const { return _values; }
public:
  unsigned& frameCount   () { return _values[0]; }
  unsigned& pauseCount   () { return _values[1]; }
  unsigned& overflowCount() { return _values[2]; }
  unsigned& idleCount    () { return _values[3]; }
private:
  std::vector<unsigned> _values;
};  

const char** DmaStats::names() {
  static const char* _names[] = {"frameCount",
                                 "pauseCount",
                                 "overflowCount",
                                 "idleCount" };
  return _names;
}


template <class T> class RateMonitor {
public:
  RateMonitor() {}
  RateMonitor(const T& o) {
    clock_gettime(CLOCK_REALTIME,&tv);
    _t = o;
  }
  RateMonitor<T>& operator=(const RateMonitor<T>& o) {
    tv = o.tv;
    _t = o._t;
    return *this;
  }
public:
  void dump(const RateMonitor<T>& o) {
    double dt = double(o.tv.tv_sec-tv.tv_sec)+1.e-9*(double(o.tv.tv_nsec)-double(tv.tv_nsec));
    for(unsigned i=0; i<_t.values().size(); i++)
      printf("%10u %15.15s [%10u] : %g\n",
             _t.values()[i],
             _t.names()[i],
             o._t.values()[i]-_t.values()[i],
             double(o._t.values()[i]-_t.values()[i])/dt);
  }
private:
  timespec tv;
  T _t;
};
  

static DaqStats  daqStats;
static HSD::Histogram readSize(8,1);
static HSD::Histogram adcSync (7,1);
static HSD::Histogram scorr   (7,1);
static uint64_t opid = 0;
static uint32_t osnc = 0;
static Module::TestPattern pattern = Module::Flash11;
enum Interleave {Q_NONE,Q_ABCD};
static Interleave qI=Q_NONE;

static unsigned nPrint = 20;

static void* read_thread(void*);
static bool checkFlashN_interleaved(uint32_t* p, const unsigned n);
static bool checkFlashN            (uint32_t* p, const unsigned n);

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options:\n");
  printf("\t-d <dev>    : device filename\n");
  printf("\t-I          : interleaved input (default False)\n");
  printf("\t-f FMC      : Card to readout (default 0)\n");
  printf("\t-B busyTime : Sleeps for busytime seconds each read\n");
  printf("\t-D delay    : Delay in 160 MHz blocks\n");
  printf("\t-E emptyThr : Set empty threshold for flow control\n");
  printf("\t-F fullThr  : \n");
  printf("\t-R rate     : Set trigger rate [0:929kHz, 1:71kHz, 2:10kHz, 3:1kHz, 4:100Hz, 5:10Hz\n");
  printf("\t-S samples  : Set reaout length in units of 160 MHz blocks\n");
  printf("\t-P partition: Set trigger source to partition\n");
  printf("\t-T pattern  : Set test pattern\n");
  printf("\t-v nPrint   : Set number of events to dump out\n");
  printf("\t-V          : Dump out all events\n");
}

static Module* reg=0;
static int partition = -1;

void sigHandler( int signal ) {
  if (reg) {
    reg->stop();
  }
  readSize.dump();
  adcSync .dump();
  scorr   .dump();
  
  printf("Last pid: %016lx\n",opid);

  ::exit(signal);
}

int main(int argc, char** argv) {
  extern char* optarg;
  const char* dev = "/dev/datadev_0";
  unsigned fmc=0;
  unsigned emptyThr=2;
  unsigned fullThr=-1U;
  unsigned length=16;  // multiple of 16
  unsigned delay=0;
  int      onechannel_input = -1;
  unsigned streams = 0xf;
  ThreadArgs args;
  args.fd = -1;
  args.busyTime = 0;
  args.reqfd = -1;
  args.rate = 6;

  int c;
  bool lUsage = false;
  while ( (c=getopt( argc, argv, "I:d:D:f:F:S:B:E:F:R:P:T:v:Vh")) != EOF ) {
    switch(c) {
    case 'I':
      qI=Q_ABCD;
      onechannel_input = strtoul(optarg,NULL,0);
      streams = 0x10;
      break;
    case 'd':
      dev = optarg;
      break;
    case 'D':
      delay = strtoul(optarg,NULL,0);
      break;
    case 'f':
      fmc = strtoul(optarg,NULL,0);
      break;
    case 'B':
      args.busyTime = strtoul(optarg,NULL,0);
      break;
    case 'E':
      emptyThr = strtoul(optarg,NULL,0);
      break;
    case 'F':
      fullThr = strtoul(optarg,NULL,0);
      break;
    case 'S':
      length = strtoul(optarg,NULL,0);
      break;
    case 'R':
      args.rate = strtoul(optarg,NULL,0);
      break;
    case 'P':
      partition = strtoul(optarg,NULL,0);
      break;
    case 'T':
      pattern = (Module::TestPattern)strtoul(optarg,NULL,0);
      break;
    case 'v':
      nPrint = strtoul(optarg,NULL,0);
      break;
    case 'V':
      lVerbose = true;
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

  //
  //  Configure channels, event selection
  //
  printf("Using %s\n",dev);

  int fd = open(dev, O_RDWR);
  if (fd<0) {
    perror("Could not open");
    return -1;
  }

  uint8_t dmaMask[DMA_MASK_SIZE];
  dmaInitMaskBytes(dmaMask);
  dmaAddMaskBytes(dmaMask,fmc<<8);
  dmaSetMaskBytes(fd,dmaMask);

  args.fd  = fd;
  sem_init(&args.sem,0,0);

  Module* p = reg = Module::create(fd,fmc);

  p->dumpMap();
  p->disable_test_pattern();
  p->enable_test_pattern(pattern);

  p->init();
  p->sample_init(length, delay, 0, onechannel_input, streams);
  p->trig_lcls( args.rate );

  //
  //  Create thread to receive DMAS and validate the data
  //
  { 
    pthread_attr_t tattr;
    pthread_attr_init(&tattr);
    pthread_t tid;
    if (pthread_create(&tid, &tattr, &read_thread, &args))
      perror("Error creating read thread");
    usleep(10000);
  }

  ::signal( SIGINT, sigHandler );

  RateMonitor<DaqStats> ostats(daqStats);
  DmaStats d;
  RateMonitor<DmaStats> dstats(d);

  unsigned och0  =0;
  unsigned otot  =0;
  unsigned rxErrs=0;
  unsigned rxErrs0 = p->tpr().RxDecErrs+p->tpr().RxDspErrs;
  unsigned rxRsts=0;
  unsigned rxRsts0 = p->tpr().RxRstDone;

  p->start();

  while(1) {
    usleep(1000000);

    printf("--------------\n");

    { RateMonitor<DaqStats> stats(daqStats);
      ostats.dump(stats);
      ostats = stats; }

#if 0    
    { unsigned v = p->tpr().RxDecErrs+p->tpr().RxDspErrs - rxErrs0;
      unsigned u = p->tpr().RxRstDone - rxRsts0;
      printf("RxErrs/Resets: %08x/%08x [%x/%x]\n", 
             v,
             u,
             v-rxErrs,
             u-rxRsts);
      rxErrs=v; rxRsts=u; }

    p->dumpBase  ();
#endif
    p->dumpStatus();
  }

  return 0;
}

void* read_thread(void* arg)
{
  ThreadArgs targs = *reinterpret_cast<ThreadArgs*>(arg);

  size_t    maxSize = 1<<26;
  uint32_t* data = new uint32_t[maxSize>>2];
  unsigned  flags;
  unsigned  error;
  unsigned  dest;
  ssize_t   nb;

  bool lLCLSII = (targs.rate<9);

  uint64_t dpid;
  switch(targs.rate) {
  case 0: dpid = 1; break;
  case 1: dpid = 13; break;
  case 2: dpid = 91; break;
  case 3: dpid = 910; break;
  case 4: dpid = 9100; break;
  case 5: dpid = 91000; break;
  case 6: dpid = 910000; break;
  case 40:dpid = 3 ; break;
  case 41:dpid = 6 ; break;
  case 42:dpid =12 ; break;
  case 43:dpid =36 ; break;
  case 44:dpid =72 ; break;
  case 45:dpid =360; break;
  case 46:dpid =720; break;
  default: dpid = 1; break;
  }
  printf("rate [%u] dpid [%lu] LCLSII [%c]\n",targs.rate,dpid,lLCLSII?'T':'F');

  //  sem_post(&targs.sem);

  while(1) {
    if ((nb = dmaRead(targs.fd, data, 1<<24, &flags, &error, &dest))>0) {
        /*
      { printf("READ %zd bytes\n",nb);
        uint32_t* p     = (uint32_t*)data;
        unsigned ilimit = (lVerbose || (nb<64)) ? (nb>>2) : 16;
        for(unsigned i=0; i<ilimit; i++)
          printf(" %08x",p[i]);
        printf("\n"); }
        */
      uint32_t* p     = (uint32_t*)data;
      {
        daqStats.eventFrames()++;
        if (lLCLSII) {
          opid = p[4];
          opid = (opid<<32) | p[3];
        }
        else {
          opid = p[2]&0x1ffff;
        }
        osnc = p[7];
      }
      break;
    }
  }

#if 0
  pollfd pfd;
  pfd.fd      = targs.fd;
  pfd.events  = POLLIN | POLLERR;
  pfd.revents = 0;
#endif

  while (1) {
#if 0
    while (::poll(&pfd, 1, 1000)<=0)
      ;
#endif
    if ((nb = dmaRead(targs.fd, data, 1<<24, &flags, &error, &dest))<=0) {
      //  timeout in driver
      continue;
    }

    uint32_t* p     = (uint32_t*)data;
    //    uint32_t  len   = p[0];
    uint64_t  pid ;
    if (lLCLSII) {
      pid = p[4];
      pid = (pid<<32) | p[3];
    }
    else {
      pid = p[2]&0x1ffff;
    }

    uint64_t  pid_busy = lLCLSII ? (opid + (1ULL<<20)) : (opid + 360);

    readSize.bump(nb>>5);
    adcSync .bump((p[7]&0xfff)>>2);
    unsigned dsnc = ((p[7]&0xfff)>>2)-((osnc&0xfff)>>2);
    //    scorr   .bump( ((dsnc+10)%10)*10 + ((p[6]>>1)*21)%10);
    scorr   .bump( ((dsnc+8)%8)*10 + ((p[6]>>1)*21)%10);

    osnc = p[5];

    if (1) {
      daqStats.eventFrames()++;

      if (nPrint) {
        nPrint--;
        printf("EVENT:");
        unsigned ilimit = (lVerbose || nb<64) ? (nb>>2) : 16;
        for(unsigned i=0; i<ilimit; i++)
          printf(" %08x",p[i]);
        printf("\n");

        const EventHeader* eh = reinterpret_cast<const EventHeader*>(p);
        eh->dump();
        const StreamHeader* sh = eh->streams().first();
        printf("StreamHeader @%p\n",sh);
        sh->dump();
      }
    
      if (pid==opid) {
        daqStats.repeatFrames()++;
        printf("repeat  [%zd]: exp %016lx: ",nb,opid+dpid);
        uint32_t* p32 = (uint32_t*)data;
        for(unsigned i=0; i<8; i++)
          printf(" %08x",p32[i]);
        printf("\n"); 
      }
      else if (pid-opid != dpid && (opid+dpid < 0x1ffe0 || opid > 0x20000) ) {
        daqStats.corrupt()++;
        printf("corrupt [%zd]: exp %016lx: ",nb,opid+dpid);
        uint32_t* p32 = (uint32_t*)data;
        for(unsigned i=0; i<8; i++)
          printf(" %08x",p32[i]);
        printf("\n"); 
      }

      switch(pattern) {
      case Module::Flash11:
        if (qI==Q_ABCD) {
          if (!checkFlashN_interleaved(p,11))
            daqStats.corrupt()++;
        }
        else {
          if (!checkFlashN(p,11))
            daqStats.corrupt()++;
        }
        break;
      case Module::Flash12:
        if (qI==Q_ABCD) {
          if (!checkFlashN_interleaved(p,12))
            daqStats.corrupt()++;
        }
        else {
          if (!checkFlashN(p,12))
            daqStats.corrupt()++;
        }
        break;
      case Module::Flash16:
        if (qI==Q_ABCD) {
          if (!checkFlashN_interleaved(p,16))
            daqStats.corrupt()++;
        }
        else {
          if (!checkFlashN(p,16))
            daqStats.corrupt()++;
        }
        break;
      default:
        break;
      }

      opid = pid;
      
      if (targs.busyTime && opid > pid_busy) {
        usleep(targs.busyTime);
        pid_busy = lLCLSII ? (opid + (1ULL<<20)) : (opid + 360);
      }
    }
  }

  printf("read_thread done\n");

  return 0;
}

bool checkFlashN_interleaved(uint32_t* p, 
                             const unsigned n)
{
  const EventHeader*  eh = reinterpret_cast<const EventHeader*>(p);
  StreamIterator iter    = eh->streams();
  const StreamHeader* sh = iter.first();
  const uint16_t*      q = sh->data();

  unsigned s=0;
  for(unsigned i=4; i<sh->samples(); i++) {
    if (q[i]==0) continue;
    if (q[i]==0x07ff) {
    //  Saturate
    //if (p[i]==0x0400) {
      s=i; break;
    }
    printf("Unexpected data [%08x] at word %u\n",
           p[i], i);
    return false;
  }
  if (s==0) {
    printf("No pattern found\n");
    return false;
  }

  for(unsigned i=s+4; i<sh->samples(); i++) {
      if (((i-s)%(4*n))<4) {
          if (q[i] != 0x07ff) {
              //  Saturate
              //if (p[i] != 0x04000400) {
              printf("Unexpected data %08x [%08x] at word %u:%u\n", q[i], 0x07ff, i, (i-s)%(4*n));
              return false;
          }
      }
      else if (q[i] != 0) {
          printf("Unexpected data %08x [%08x] at word %u:%u\n", q[i],0,i,(i-s)%(4*n));
          return false;
      }
  }
  return true;
}

bool checkFlashN(uint32_t* p,
                 const unsigned n)
{
  const EventHeader*  eh = reinterpret_cast<const EventHeader*>(p);
  StreamIterator iter    = eh->streams();
  const StreamHeader* sh = iter.first();
  const uint16_t*      q = sh->data();

  int s=-1;
  for(unsigned i=0; i<sh->samples(); i++) {
    if (q[i]==0) continue;
    if (q[i]==0x07ff) {
    //  Saturate
    //if (q[i]==0x0400) {
      s=i; break;
    }
    printf("Unexpected data [%04x] at word %u\n",
           q[i], i);
    return false;
  }
  if (s==-1) {
    printf("No pattern found\n");
    return false;
  }

  for(unsigned j=0; sh; j++) {
      for(unsigned i=s; i<sh->samples(); i++) {
          q  = sh->data();
          if (((i-s)%n)==0) {
              if (q[i] != 0x07ff) {
                  //  Saturate
                  //if (q[i] != 0x0400) {
                  printf("Unexpected data %04x [%04x] at word %u.%u:%u\n", q[i], 0x07ff, j, i, s);
                  return false;
              }
          }
          else if (q[i] != 0) {
              printf("Unexpected data %04x [%04x] at word %u.%u:%u\n", q[i],0,j,i,s);
              return false;
          }
      }
      sh = iter.next();
  }
  return true;
}
