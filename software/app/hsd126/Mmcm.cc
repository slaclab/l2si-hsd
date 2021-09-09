#include "Mmcm.hh"

#include <stdio.h>

using namespace Pds::HSD;

void Mmcm::setLCLS(unsigned delay_int, unsigned delay_frac)
{
  PowerU = 0xffff;

  const unsigned m = 10;
  _setFbMult(m);
  _setClkDiv(delay_int, delay_frac);
  _setLock  (m);
  _setFilt  (m);

  //  PowerU = 0;
}

void Mmcm::setLCLSII(unsigned delay_int, unsigned delay_frac)
{
  PowerU = 0xffff;

  const unsigned m = 6;
  _setFbMult(m);
  _setClkDiv(delay_int, delay_frac);
  _setLock  (m);
  _setFilt  (m);

  //  PowerU = 0;
}

//  only compiles on rhel7
#if 0
static const uint64_t _lock[64] = {
  // This table is composed of:
  // LockRefDly(5b):LockFBDly(5b)LockCnt(10b)LockSatHigh(10b)UnlockCnt(10b)
  0b0011000110111110100011111010010000000001,
  0b0011000110111110100011111010010000000001,
  0b0100001000111110100011111010010000000001,
  0b0101101011111110100011111010010000000001,
  0b0111001110111110100011111010010000000001,
  0b1000110001111110100011111010010000000001,
  0b1001110011111110100011111010010000000001,
  0b1011010110111110100011111010010000000001,
  0b1100111001111110100011111010010000000001,
  0b1110011100111110100011111010010000000001,
  0b1111111111111000010011111010010000000001,
  0b1111111111110011100111111010010000000001,
  0b1111111111101110111011111010010000000001,
  0b1111111111101011110011111010010000000001,
  0b1111111111101000101011111010010000000001,
  0b1111111111100111000111111010010000000001,
  0b1111111111100011111111111010010000000001,
  0b1111111111100010011011111010010000000001,
  0b1111111111100000110111111010010000000001,
  0b1111111111011111010011111010010000000001,
  0b1111111111011101101111111010010000000001,
  0b1111111111011100001011111010010000000001,
  0b1111111111011010100111111010010000000001,
  0b1111111111011001000011111010010000000001,
  0b1111111111011001000011111010010000000001,
  0b1111111111010111011111111010010000000001,
  0b1111111111010101111011111010010000000001,
  0b1111111111010101111011111010010000000001,
  0b1111111111010100010111111010010000000001,
  0b1111111111010100010111111010010000000001,
  0b1111111111010010110011111010010000000001,
  0b1111111111010010110011111010010000000001,
  0b1111111111010010110011111010010000000001,
  0b1111111111010001001111111010010000000001,
  0b1111111111010001001111111010010000000001,
  0b1111111111010001001111111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001,
  0b1111111111001111101011111010010000000001
};

// low bandwidth
static const uint16_t _filter_low[] = {
  // CPRES(4b)LF(4b)HF(2b)
  0b0010111111,
  0b0010111111,
  0b0010111111,
  0b0010111111,
  0b0010111111,
  0b0010111111,
  0b0010011111,
  0b0010011111,
  0b0010011111,
  0b0010110111,
  0b0010110111,
  0b0010110111,
  0b0010001111,
  0b0010010111,
  0b0010010111,
  0b0010010111,
  0b0010100111,
  0b0010100111,
  0b0010111011,
  0b0010111011,
  0b0010111011,
  0b0010111011,
  0b0010111011,
  0b0010111011,
  0b0010000111,
  0b0010000111,
  0b0010000111,
  0b0010000111,
  0b0010000111,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010011011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010101011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011,
  0b0010110011
};

// high bandwidth
static const uint16_t _filter_high[] = {
  // CPRES(4b)LF(4b)HF(2b)
  0b0010111111,
  0b0010111111,
  0b0010101111,
  0b0011111111,
  0b0100111111,
  0b0100111111,
  0b0101111111,
  0b0110111111,
  0b0111111111,
  0b0111111111,
  0b1100111111,
  0b1101111111,
  0b0001111111,
  0b1111111111,
  0b1111111111,
  0b1110011111,
  0b1110101111,
  0b1111011111,
  0b1111101111,
  0b1111101111,
  0b1110110111,
  0b1111110111,
  0b1111110111,
  0b1111001111,
  0b1111001111,
  0b1111001111,
  0b1110010111,
  0b1110010111,
  0b1110010111,
  0b1111010111,
  0b1111010111,
  0b1111010111,
  0b1111100111,
  0b1111100111,
  0b1111100111,
  0b1111100111,
  0b1111100111,
  0b1110111011,
  0b1110111011,
  0b1110111011,
  0b1110111011,
  0b1111111011,
  0b1111111011,
  0b1111111011,
  0b1111111011,
  0b1111111011,
  0b1111111011,
  0b1111111011,
  0b1110000111,
  0b1110000111,
  0b1110000111,
  0b1110000111,
  0b1110000111,
  0b1100011011,
  0b1100011011,
  0b1100011011,
  0b1100011011,
  0b1100011011,
  0b1100011011,
  0b1100011011,
  0b1100101011,
  0b1100101011,
  0b1100101011,
  0b1100101011
};
#else
static const uint64_t _lock[] = {0};
static const uint16_t _filter_low[] = {0};
static const uint16_t _filter_high[] = {0};
#endif


void Mmcm::_setFbMult(unsigned m)
{
  unsigned u,v;
  // CLKFBOUT_MULT_F_G = 10, Fvco = 10*119MHz = 1.19GHz
  u = ClkFbOut_1;
  v = u;
  v &= ~0xefff;
  v |= ((m>>1)&0x3f)<<0;
  v |= ((m-(m>>1))&0x3f)<<6;
  printf("ClkFbOut_1 %x -> %x\n", u, v);
  ClkFbOut_1 = v;

  u = ClkFbOut_2;
  v  = u;
  v &= ~0x7fff;
  v |= (2&0x3)<<8;   // MX (required)
  printf("ClkFbOut_2 %x -> %x\n", u, v);
  ClkFbOut_2 = v;
}

void Mmcm::_setClkDiv(unsigned delay_int, unsigned delay_frac)
{
  unsigned u,v;
  // CLKOUT0_DIVIDE_F_G = 12.5, Fclk0 = Fvco/12.5 = 95.2MHz
  u = ClkOut0_1;
  v = u;
  v &= ~0xefff;
  v |= (5&0x3f)<<0;
  v |= (5&0x3f)<<6;
  v |= (delay_frac&0x7)<<13; // Fractional delay of vco
  printf("ClkOut0_1 %x -> %x\n", u, v);
  ClkOut0_1 = v;

  u  = ClkOut0_2;
  v  = u;
  v &= ~0x7fff;
  v |= (delay_int&0x3f)<<0;  // Integer delay of vco
  v |= (2&0x3)<<8;           // MX (required)
  v |= ((4&0x7)<<12) | (1<<11) | (1<<10); // Frac = 4/8
  printf("ClkOut0_2 %x -> %x\n", u, v);
  ClkOut0_2 = v;

  u  = ClkOut5_2;
  v  = u;
  v &= ~0xf300;
  v |= 0x2<<8;
  v |= 1<<12;
  v |= 0x2<<13;  // falling edge at 1/4 cycle
  printf("ClkOut5_2 %x -> %x\n", u, v);
  ClkOut5_2 = v;

  u  = DivClk;
  v  = u;
  v &= ~0x3fff;
  v |= (3<<12);
  printf("DivClk %x -> %x\n", u, v);
  DivClk = v;
}

void Mmcm::_setLock(unsigned m)
{
  unsigned u,v;
  const uint64_t lock_entry = _lock[m-1];
  u = Lock_1;
  v = u;
  v &= ~0x3ff;
  v |= (lock_entry>>20)&0x3ff;
  printf("Lock_1 %x -> %x\n", u, v);
  Lock_1 = v;

  u = Lock_2;
  v = u;
  v &= ~0x7fff;
  v |= ((lock_entry>>30)&0x1f)<<10;
  v |= ((lock_entry>>0)&0x3ff)<<0;
  printf("Lock_2 %x -> %x\n", u, v);
  Lock_2 = v;

  u = Lock_3;
  v = u;
  v &= ~0x7fff;
  v |= ((lock_entry>>35)&0x1f)<<10;
  v |= ((lock_entry>>10)&0x3ff)<<0;
  printf("Lock_3 %x -> %x\n", u, v);
  Lock_3 = v;
}

void Mmcm::_setFilt(unsigned m)
{
  uint32_t u,v;
  const uint16_t filter_entry = _filter_high[m-1];

  u = Filt_1;
  v = u;
  v &= ~(0x9900);
  v |= ((filter_entry>>9)&0x1)<<15;
  v |= ((filter_entry>>7)&0x3)<<11;
  v |= ((filter_entry>>6)&0x1)<<8;
  printf("Filt_1 %x -> %x\n", u, v);
  Filt_1 = v;

  u = Filt_2;
  v = u;
  v &= ~(0x9990);
  v |= ((filter_entry>>5)&0x1)<<15;
  v |= ((filter_entry>>3)&0x3)<<11;
  v |= ((filter_entry>>1)&0x3)<<7;
  v |= ((filter_entry>>0)&0x1)<<4;
  printf("Filt_2 %x -> %x\n", u, v);
  Filt_2 = v;
}
