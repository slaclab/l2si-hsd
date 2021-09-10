
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
    printf("Options: -d <dev> [device file    ; default: /dev/datadev_0]\n");
    printf("         -1(2)    [single (dual) channel       ; default: 1]\n");
    printf("         -A(B)    [A0/2 (A1/3) is primary input; default: A]\n");
}

int main(int argc, char** argv) {

    extern char* optarg;
    char* endptr;

    const char* dev="/dev/datadev_0";
    bool lDualCh = false;
    InputChan inputCh = CHAN_A0_2;
    int c;
    bool lUsage = false;

    while ( (c=getopt( argc, argv, "d:12ABh")) != EOF ) {
        switch(c) {
        case 'd':
            dev = optarg;
            break;
        case '1':
            lDualCh = false;
            break;
        case '2':
            lDualCh = true;
            break;
        case 'A':
            inputCh = CHAN_A0_2;
            break;
        case 'B':
            inputCh = CHAN_A1_3;
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
    m->setup_jesd(false,adccal,adccal,lDualCh,inputCh);

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
