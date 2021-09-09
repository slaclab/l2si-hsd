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

#include "Module134.hh"
#include "Fmc134Ctrl.hh"
#include "Event.hh"
#include "DmaDriver.h"
#include "Reg.hh"

using namespace Pds::HSD;

extern int optind;

void usage(const char* p) {
    printf("Usage: %s [options]\n",p);
    printf("Options:\n");
    printf("\t-d <dev>    : device file (default /dev/datadev_0)\n");
    printf("\t-n <events> : acquire <nevents> events\n");
    printf("\t-L <samples>: samples to acquire\n");
    printf("\t-T <lo,hi>  : sparsification range\n");
    printf("\t-P          : enable ramp test pattern\n");
}

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
    bool lDecompress = false;
    bool lPattern    = false;
    unsigned length  = 40;  
    unsigned nevents = 10;
    unsigned eventcode = 45;
    //  sparsify values between lo_threshold and hi_threshold
    FexParams q;
    q.lo_threshold=0;
    q.hi_threshold=0;
    q.rows_before =2;
    q.rows_after  =2;
    char* endptr;
  
    while ( (c=getopt( argc, argv, "d:e:n:hDL:PT:")) != EOF ) {
        switch(c) {
        case 'd':
            dev = optarg;
            break;
        case 'e':
            eventcode = strtoul(optarg,NULL,0);
            break;
        case 'n':
            nevents = strtoul(optarg,NULL,0);
            break;
        case 'D':
            lDecompress = true;
            break;
        case 'L':
            length = strtoul(optarg,NULL,0);
            break;
        case 'P':
            lPattern = true;
            break;
        case 'T':
            q.lo_threshold = strtoul(optarg  ,&endptr,0);
            q.hi_threshold = strtoul(endptr+1,&endptr,0);
            if (*endptr==',') {
                q.rows_before = strtoul(endptr+1,&endptr,0);
                if (*endptr==',')
                    q.rows_after = strtoul(endptr+1,&endptr,0);
            }
            printf("Using fex parameters lo[%x] hi[%x] before[%x] after[%x]\n",
                   q.lo_threshold, q.hi_threshold, q.rows_before, q.rows_after);
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

    Module134* p = Module134::create(fd);
    p->dumpMap();

    if (lPattern)
        p->enable_test_pattern(Module134::Ramp);
    else
        p->disable_test_pattern();

    p->stop();

    // "Rows" of data 
    // 1 row = 8 samples four channel mode or 
    //        32 samples one channel mode)

    //  Acquire all 4 streams for each chip
    //     0 : 3200m channel 0
    //     1 : 3200m channel 1
    //     2 : 6400m
    //     3 : 6400m sparsified
    length = 32*(length/32);
    //  One channel readout (interleaved)
    unsigned channel = 0; // input channel
    p->sample_init(length, 1, 0, channel, 0xff, q);

    //  Setup trigger
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

    bool lprint=true;

    for(unsigned ievt = 0; ievt < nevents; ) {
        lprint &= (ievt < 10);
        bool lErr=false;
        const uint16_t SMP_LO = 0x000, SMP_HI = 0x1000;
        const uint16_t* sdata[4];
        if ((nb = dmaRead(fd, data, maxSize, &flags, &error, &dest))>0) {
            sizeMap[nb]++;
            ievt++;
            const EventHeader* eh = reinterpret_cast<const EventHeader*>(data);
            StreamIterator it = eh->streams();
            for(const StreamHeader* sh = it.first(); sh; sh=it.next()) {
                uint16_t s0;
                const uint16_t* samples = sh->data();
                //  sanity checks
                //  No sparsification in other streams
                if (sh->stream_id()<3) {
                    sdata[sh->stream_id()] = samples;
                    for(unsigned i=0; i<sh->samples(); i++) {
                        if (samples[i]&0x8000) {
                            printf("Found skip samples in unsparsified stream\n");
                            lErr=true;
                        }
                        // Check pattern
                        if (lPattern) {
                            if (i==0 && sh->stream_id()==0)
                                s0 = samples[i];
                            else if (sh->stream_id()<2 && samples[i] != ((s0+i)&0x7ff)) {
                                printf("Pattern error at sample %d (%x/%x)\n",
                                       i, samples[i], ((s0+i)&0x7ff));
                                lErr=true;
                            }
                        }
                        // Check range
                        else if (samples[i]<SMP_LO || samples[i]>SMP_HI) {
                            printf("Found samples out of range\n");
                            lErr=true;
                        }
                    }
                }
                //  Check series of 4 skip-samples
                else {
                    for(unsigned i=0,j=0; i<sh->samples(); i++) {
                        if (samples[i]&0x8000) {
                            j += samples[i]&0x7fff;
                            for(unsigned k=0; k<3; k++)
                                if (samples[++i]!=0x8000) {
                                    printf("Found non-zero skip sample after 1st skip\n");
                                    lErr=true;
                                }
                        }
                        else {
                            if (samples[i] != sdata[j&1][j>>1]) {
                                printf("Interleaved sample %u (%x,%x) disagrees\n",j,samples[i],sdata[j&1][j>>1]);
                                lErr=true;
                            }
                            j++;
                        }
                    }                
                }
                if (sh->stream_id()==3 && lDecompress && lprint) {
                    //  decompress
                    printf("  --decompressed\n");
                    const std::vector<uint16_t> s = _decompress(samples,length,(q.lo_threshold+q.hi_threshold)/2);
                    for(unsigned i=0; i<s.size(); i++)
                        printf(" %04x", s[i]);
                    printf("\n");
                }
            }
            if (lprint || lErr) {
                printf("---\n");
                printf("Read %zu bytes:  Dest 0x%x  %s\n",nb, dest, (dest>>8)?"A2/3":"A0/1");
                eh->dump();
                for(const StreamHeader* sh = it.first(); sh; sh=it.next()) {
                    sh->dump();
                    const uint16_t* samples = sh->data();
                    for(unsigned i=0; i<sh->samples(); i++)
                        printf(" %04x", samples[i]);
                    printf("\n");
                }
            }
        }
        if (lErr) {
            printf("%u events\n",ievt);
            break;
        }
    }

    p->stop();

    delete[] data;

    for(std::map<unsigned,unsigned>::iterator it=sizeMap.begin(); it!=sizeMap.end(); it++) {
        printf("sizeMap[%u] : %u\n", it->first, it->second);
    }

    return 0;
}
