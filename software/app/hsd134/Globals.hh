#ifndef Pds_HSD_Globals_hh
#define Pds_HSD_Globals_hh

#include <stdint.h>

typedef volatile uint32_t vuint32_t;

enum TimingType { LCLS, LCLSII, EXTERNAL, K929, M3_7, M7_4, M64 };
enum InputChan  { CHAN_A0_2, CHAN_A1_3 };

#endif
