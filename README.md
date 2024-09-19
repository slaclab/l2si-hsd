# lcls2-hsd
High speed digitizer for SLAC LCLS2 Data Acquisition


   ADC Reference clock generation

   FMC134
    4 channels per board (nom 3.2 GS/s).
    2 interleaved-channels per board (nom 6.4 GS/s)
    LCLSI
    1/14 MHz, 119 MHz 
    refClk = 119 MHz*40/49 = 97.1428 MHz
    adcClk = 155.428 MHz = 71kHz * 2176
    sampling rate = 40*adcClk = 6.2171428 GS/s (interleaved)

    LCLSII
    929kHz (*200 = 185.7MHz)
    refClk = 185.7/2 = 92.857 MHz
    adcClk = 160MHz * 13/14 = 929kHz *160
    sample rate = 40*adcClk = 5.942857 GS/s (interleaved)

   FMC126
    4 channels per board (nom 1.25 GS/s)
    1 interleaved channel per board (nom 5 GS/s)
    LCLSI
    refClk = 119 MHz*10.5/125 = 9.996 MHz
    sampling rate = 2*250*refClk = 4.998 GS/s (interleaved)

    LCLSII
    refClk = 1300/1400 MHz*16 = 14.85714 MHz
    sampling rate = 4*168.5*refClk = 5.006856 GS/s (interleaved)

    
Some limits:
     hsd_6400m_dma_*
	max waveform length = 4096 rows (40 samples/row)
	max gate length     = 2**20 rows (6.73 ns/row SC, 6.47 ns/row NC)

Rework for synchronousl clocking:
  FMC126
    +---------------------------------------------+
    |A1                                           |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooo*ooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |K1                                           |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    | o o  o o  o o  o o  o o  o o  o o  o o  o o |
    |  o    o    o    o    o    #    o    o    o  |
    | o o  o o  o o  o o  o o  o o  o o  o o  o o |
    +---------------------------------------------+
       A1   A0   R0   R1   CO   CI   TR   A3   A2
      
  FMC134
    FPGA AL24 (pllRefClk)  ->  FMC F5 (HA00_N_CC) [*]
      -> H23 on FM134 reverse side (stacked connector)
     connect to FMC134 CI center pin [#]

    +---------------------------------------------+
    |A1                                           |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooo*ooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |   oooooooooooooooooooooooooooooooooooooooo  |
    |K1                                           |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    |                                             |
    | o o  o o  o o  o o  o o  o o  o o  o o  o o |
    |  o    o    o    o    o    #    o    o    o  |
    | o o  o o  o o  o o  o o  o o  o o  o o  o o |
    +---------------------------------------------+
       A1   A0   R0   R1   CO   CI   TR   A3   A2
      