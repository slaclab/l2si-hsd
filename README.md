# lcls2-hsd
High speed digitizer for SLAC LCLS2 Data Acquisition


   ADC Reference clock generation

    LCLSI
    1/14 MHz, 119 MHz 
    refClk = 119 MHz*40/49 = 97.1428 MHz
    adcClk = 155.428 MHz = 71kHz * 2176
    sampling rate = 32*adcClk = 3.1085714 GS/s
    
    LCLSII
    929kHz (*200 = 185.7MHz)
    refClk = 185.7/2 = 92.857 MHz
    adcClk = 160MHz * 13/14 = 929kHz *160
  

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
      