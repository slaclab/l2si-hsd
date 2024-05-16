
import pyrogue as pr
import time

i2cSwitchPort = { 'PrimaryFmc':1, 'SecondaryFmc':2, 'SFP':4, 'LocalBus':8 }

class AxiLiteMasterProxy(pr.Device):
    def __init__(   self,
                    name        = "AxiLiteMasterProxy",
                    description = "Proxy for Axi-Lite transactions",
                    **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        def addvar(name,offset,mode='RW'):
            self.add(pr.RemoteVariable(
                name     = name,
                offset   = offset,
                bitSize  = 32,
                mode     = mode,
                verify   = False))

        addvar('rnw' ,0x0)
        addvar('cmpl',0x4,'RO')
        addvar('addr',0x8)
        addvar('valu',0xc)

    def readI2c(self, offset):
        addr = offset + self._getAddress() - self._getOffset()
        self.addr.set(addr)
        self.rnw .set(1)
        self.wait_for_complete(f'readI2c reading {offset}')
        return self.valu.get()

    def writeI2c(self, offset, value):
        addr = offset + self._getAddress() - self._getOffset()
        self.valu.set(value)
        self.addr.set(addr)
        self.rnw .set(0)
        self.wait_for_complete(f'writeI2c writing {value} to  {offset}')

    def wait_for_complete(self,msg):
        tmo = 0
        tmo_mask = 3
        while(True):
            time.sleep(1.e-3)
            # print('complete3 = ',self.cmpl.get()&1)
            tmo += 1
            if (tmo&tmo_mask)==tmo_mask:
                tmo_mask = (tmo_mask<<1) | 1
                print(f'{msg}: tmo {tmo}')
            if (self.cmpl.get()&1) == 1:
                # print('tmo = ',tmo)
                break


class FmcCpld(object):
    def __init__(self,proxy,offset):
        self.proxy= proxy
        self.offset  = offset
        self.command  = offset + 0x0
        self.i2c_data0  = offset + 0x18
        self.i2c_data1  = offset + 0x1C
        self.i2c_data2  = offset + 0x20
        self.i2c_data3  = offset + 0x24
        self.i2c_read0  = offset + 0x28
        self.i2c_read1  = offset + 0x2C
        self.i2c_read2  = offset + 0x30
        self.i2c_read3  = offset + 0x34
        # some constants
        self.ADC0= 1
        self.ADC1= 2
        self.ADC_BOTH= 3
        self.LMX =4
        self.LMK =8
        self.HMC =10
        self.UNITAPI_OK = 0
        self.cpld_address =  0
        self.CLOCKTREE_CLKSRC_INTERNAL = 0 
        self.CLOCKTREE_CLKSRC_EXTERNAL = 1
        self.CLOCKTREE_REFSRC_EXTERNAL = 2
        self.CLOCKTREE_REFSRC_STACKED = 3
        self.FMC134_CLOCKTREE_ERR_OK = 0
        self.FMC134_ADC_ERR_OK       = 0
        self.FMC134_ERR_ADC_INIT     = 1
        self.AdcCalibMode = ['NO_CAL', 'FG_CAL', 'BG_CAL']

    def _writeRegister(self, dev, addr, val):
        data=0
        if dev==self.LMK:
            data |= (addr & 0x1fff) << 16
            data |= (val & 0xff) << 8
        elif dev==self.LMX:
                data |= (addr & 0xf)
                data |= (val & 0xfffffff) <<4
        elif dev==self.HMC:
            data |= (1<<16)
            data |= (addr & 0xf) << 19
            data |= (val & 0x1ff) << 23
        else:
            data |= (addr&0x7fff) << 16
            data |= (val & 0xff) << 8
        self.proxy.writeI2c(self.i2c_data0,data)
        self.proxy.writeI2c(self.i2c_data1,data>>8)
        self.proxy.writeI2c(self.i2c_data2,data>>16)
        self.proxy.writeI2c(self.i2c_data3,data>>24)
        self.proxy.writeI2c(self.command, dev)
        time.sleep(0.01)

    def _read(self):
        return ((self.proxy.readI2c(self.i2c_read0)&0xff)<< 0) | ((self.proxy.readI2c(self.i2c_read1)&0xff)<< 8) | ((self.proxy.readI2c(self.i2c_read2)&0xff)<<16) | ((self.proxy.readI2c(self.i2c_read3)&0xff)<<24) 

    def _readRegister(self, dev, addr):
        data=0
        if dev==self.LMK:
            data |= (1<<31)
            data |= (addr & 0x1fff) << 16
        elif dev==self.LMX:
                data |= (addr & 0xf)<<5
                data |= (1<<10)
                data |= 6
        elif dev==self.HMC:
            return -1
        else:
            data |= (1<<31)
            data |= (addr&0x7fff) << 16
        self.proxy.writeI2c(self.i2c_data0,data)
        self.proxy.writeI2c(self.i2c_data1,data>>8)
        self.proxy.writeI2c(self.i2c_data2,data>>16)
        self.proxy.writeI2c(self.i2c_data3,data>>24)
        self.proxy.writeI2c(self.command, dev)
        time.sleep(0.01)
        if dev==self.LMX: 
            self.proxy.writeI2c(self.command, dev)
            time.sleep(0.01)
            data = self._read()
        else:
            data = self.proxy.readI2c(self.i2c_read1)&0xff

        return data


    def default_clocktree_init(self, clockmode):
        rc = self.UNITAPI_OK
        dword = 0
        samplingrate_setting = 0x6020000
        rc = self.internal_ref_and_lmx_enable(clockmode=clockmode)
        print('rc = self.internal_ref_and_lmx_enable(clockmode=clockmode)', rc )
        time.sleep(0.1)
        #LMX Programming for 3.2GHz
        self._writeRegister(self.LMX,  5, 0x4087001)   # Force a Reset (default from codebuilder) 0x021F7001 << from data sheet default
        # dword81 = self._readRegister(self.LMX, 5) 
        # print('dword81 = ',dword81)
        # dword81 =self._read()
        # print('dword81 = ',dword81)
        data45 = self.proxy.readI2c(0x04)
        print('data45 =', data45)

        self._writeRegister(self.LMX, 13, 0x4080C10)    # FOR 100MHz PDF  DLD TOL 1.7ns  0x4080C10


        self._writeRegister(self.LMX,  10, 0x210050C)
        self._writeRegister(self.LMX,   9, 0x03C7C03)
        self._writeRegister(self.LMX,   8, 0x207DDBF)
        self._writeRegister(self.LMX,   7, 0x004E211)      

        self._writeRegister(self.LMX,  6, 0x000004C)
        

        self._writeRegister(self.LMX,  5, 0x0030808)    # 0x0030800 = 68MHz < OSC_FREQ < 128M     0x005080 = OSC_Freq > 512MHz         0x0010800 = OSC_FREQ =< 64MHz

        self._writeRegister(self.LMX,  4, 0x0000000)

        self._writeRegister(self.LMX,  3, 0x20040BE)   # 68B4: A=45 B=40  63B4: A=45 B=35   6DBC: A=47 B=45



        self._writeRegister(self.LMX,  2, 0x0FD0902)    # 0,0,OSCx2 = 0, 0, CPP=1, 1, PLL denom dont care 
        if(rc!=self.UNITAPI_OK):
            return rc;                                               #default is 0x0FD0902

        self._writeRegister(self.LMX,  1, 0xF800001)   #6000001  Rdivider = 1 no division   C6000008  Rdivider = 8 (800 MHz Ref 100PFD)    C6000009  Rdivider = 9 (900MHz Ref 100PFD)

        self._writeRegister(self.LMX,  0, samplingrate_setting)     
        
        time.sleep(0.3)

        self._writeRegister(self.LMX,  0, samplingrate_setting)

        # HMC Programming
        self._writeRegister(self.HMC, 0x0, 0x1)         # Clear Reset

        self._writeRegister(self.HMC, 0x1, 0x1 )                # Chip enable
            
        self._writeRegister(self.HMC, 0x2, 0x91)                # Enable buffers 1, 5, and 8 x91 default
            
        self._writeRegister(self.HMC, 0x3, 0x1A)                # Use internal DC bias string, no internal LVPECL term, 100 ohm differential input term, toggle RFBUF XOR
        if(rc!=self.UNITAPI_OK):
            return rc                                               #default 1A
            
        self._writeRegister(self.HMC, 0x4, 0x00 )               # (x05) 3dBm gain FOR BRING-UP ONLY!!!
            
        self._writeRegister(self.HMC, 0x5, 0x3A)                # "Biases" with reserved values...

        # self.LMK Programming
        rc = self.reset_clock_chip()                                                # Reset clock chip

        time.sleep(0.005)

        self._writeRegister(self.LMK, 0x000 , 0x80 )    # Force a Reset
        self._writeRegister(self.LMK, 0x000 , 0x00 )    # Clear reset
        self._writeRegister(self.LMK, 0x000 , 0x10 )    # Force SPI to be 4-Wire
        self._writeRegister(self.LMK, 0x148 , 0x33 )    # CLKIN_SEL0_MUX Configured as self.LMK MISO Push Pull Output
        self._writeRegister(self.LMK, 0x002 , 0x00 )   # POWERDOWN Disabled (Normal Operation)     
        # CLK0/1 Settings GBTCLK0 and GBTCLK1 M2C LVDS both at 320MHz
        self._writeRegister(self.LMK, 0x100 , 0x0A )    # DCLK0_1_DIV DIV_BY_10 = 320MHz 
        self._writeRegister(self.LMK, 0x101 , 0x00 )    # DCLK0_1_DDLY = 0
        self._writeRegister(self.LMK, 0x102 , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout0_1 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK0_1_DDLY[9:8] = 0, DCLK0_1_DIV[9:8 = 0
        self._writeRegister(self.LMK, 0x103 , 0x40 )    # 0 1 0 0      0 0 0 0         n/a, halfstep delay PD, CLK0 = DCLK, DCLK0 active, Dclk use divider, no_duty_cyc_cor, DCLK0_Norm_Polarity, DCLK0_No_Halfstep
        self._writeRegister(self.LMK, 0x104 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, CLK1 = DCLK, DCLK1 active, SCLK_DIS_MODE = 00, DCLK1_Norm_Polarity, DCLK1_No_Halfstep
        self._writeRegister(self.LMK, 0x105 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x106 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x107 , 0x11 )   # 0 0 0 1  0 0 0 1             LVDS, LVDS 
        # CLK2/3 Settings Output to FPGA 160MHz and SYSREF     may want to turn off DCLK
        self._writeRegister(self.LMK, 0x108 , 0x14 )    # DCLK2_3_DIV DIV_BY_20 = 160MHz 
        self._writeRegister(self.LMK, 0x109 , 0x00 )    # DCLK2_3_DDLY = 0
        self._writeRegister(self.LMK, 0x10A , 0x70 )   # 0 1 1 1  0 0 0 0             CLKout2_3 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK2_DIV8,9 = 0 DCLK3_DIV8,9 = 0
        self._writeRegister(self.LMK, 0x10B , 0x40 )    # 0 1 0 0      0 0 0 0         n/a, halfstep_delay_PD, CLK2 = DCLK, DCLK2 active, Dclk use divider, no_duty_cyc_cor, DCLK2_Norm_Polarity, DCLK2_No_Halfstep
        self._writeRegister(self.LMK, 0x10C , 0x20 )    # 0 0 1 0  0 0 0 0             n/a,  na, CLK3 = SCLK, DCLK3 active, SCLK_DIS_MODE = 00, DCLK3_Norm_Polarity, DCLK3_No_Halfstep
        self._writeRegister(self.LMK, 0x10D , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, SYSREF Analog_Delay disable, analog delay = 00000
        self._writeRegister(self.LMK, 0x10E , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x10F , 0x11 )    # 0 0 0 1  0 0 0 1             LVDS, LVDS
    
        # CLK4/5 Settings  CLK4 Power-down CLK5 = ADC1_SYSREF LVPECL
        self._writeRegister(self.LMK, 0x110 , 0x20 )    # DCLK4_5_DIV DIV_BY_16 = 200MHz - not used
        self._writeRegister(self.LMK, 0x111 , 0x00 )    # DCLK4_5_DDLY = 0
        self._writeRegister(self.LMK, 0x112 , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout4_5 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK4_DIV8,9 = 0 DCLK5_DIV8,9 = 0
        self._writeRegister(self.LMK, 0x113 , 0x40 )    # 0 1 0 1      0 0 0 0         n/a, halfstep_delay_PD, CLK4 = DCLK, DCLK4_5_PD, DCLK4_5_BYP, no_duty_cyc_cor, DCLK4_Norm_Polarity, DCLK4_No_Halfstep
        self._writeRegister(self.LMK, 0x114 , 0x20 )    # 0 0 1 0  0 0 0 0             n/a,  na, CLK5 = SYSREF, SCLK4_5_PD active, SCLK_DIS_MODE = 00, DCLK3_Norm_Polarity, DCLK3_No_Halfstep
        self._writeRegister(self.LMK, 0x115 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x116 , 0x00 )   # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x117 , 0x60 )    # 0 1 1 0  0 0 0 0             CLK5 = LVPECL 2000mV, clk4_OFF
    
        # CLK6/7 CLK6 = ************** POWERDOWN *********** ADC1 CLOCK @ 3200MHz
        self._writeRegister(self.LMK, 0x118 , 0x02 )    # DCLK6_7_DIV DIV_BY_2 = 1600MHz  - not used
        self._writeRegister(self.LMK, 0x119 , 0x00 )    # DCLK6_7_DDLY = 0
        self._writeRegister(self.LMK, 0x11A , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout6 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK6_DIV 8,9 = 0 DCLK7_DIV 8,9 = 0
        self._writeRegister(self.LMK, 0x11B , 0x48 )    # 0 1 0 0      1 0     0 0            n/a, halfstep delay PD, CLK6 = DCLK, DCLK6 active, Dclk6_BYPASS_DIV, no_duty_cyc_cor, DCLK6_Norm_Polarity, DCLK6_No_Halfstep
        self._writeRegister(self.LMK, 0x11C , 0x30 )    # 0 0 1 1  0 0 0 0             n/a,  na, CLK7 = SYSCLK, DCLK7_PD, SCLK_DIS_MODE = 00, DCLK7_Norm_Polarity, DCLK7_No_Halfstep
        self._writeRegister(self.LMK, 0x11D , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x11E , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x11F , 0x00 )    # 0 0 0 0  0 0 0 0             Off
    
        # CLK8/9 CLK8 = ************** POWERDOWN *********** ADC0 CLOCK @ 3200MHz
        self._writeRegister(self.LMK, 0x120 , 0x02 )    # DCLK8_9_DIV DIV_BY_2 = 1600MHz  - not used
        self._writeRegister(self.LMK, 0x121 , 0x00 )    # DCLK8_9_DDLY = 0
        self._writeRegister(self.LMK, 0x122 , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout8 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK8_DIV 8,9 = 0 DCLK9_DIV 8,9 = 0
        self._writeRegister(self.LMK, 0x123 , 0x48 )    # 0 1 0 0      1 0     0 0            n/a, halfstep delay PD, CLK8 = DCLK, DCLK8 active, Dclk8_BYPASS_DIV, no_duty_cyc_cor, DCLK8_Norm_Polarity, DCLK8_No_Halfstep
        self._writeRegister(self.LMK, 0x124 , 0x30 )    # 0 0 1 1  0 0 0 0             n/a,  na, CLK9 = SYSCLK, DCLK9_PD, SCLK_DIS_MODE = 00, DCLK9_Norm_Polarity, DCLK9_No_Halfstep
        self._writeRegister(self.LMK, 0x125 , 0x00 )   # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x126 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x127 , 0x00 )    # 0 0 0 0  0 0 0 0             Off
    
        # CLK10/11 Settings  CLK10 Power-down CLK11 = ADC0_SYSREF LVPECL
        self._writeRegister(self.LMK, 0x128 , 0x20 )    # DCLK10_11_DIV DIV_BY_16 = 200MHz - not used
        self._writeRegister(self.LMK, 0x129 , 0x00 )    # DCLK10_11_DDLY = 0
        self._writeRegister(self.LMK, 0x12A , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout10_11 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK10_11_DIV8,9 = 0 DCLK10_11_DIV8,9 = 0
        self._writeRegister(self.LMK, 0x12B , 0x40 )    # 0 1 0 1      0 0 0 0         n/a, halfstep_delay_PD, CLK10 = DCLK, DCLK10_11_PD, DCLK10_11_BYP, no_duty_cyc_cor, DCLK10_Norm_Polarity, DCLK10_No_Halfstep
        self._writeRegister(self.LMK, 0x12C , 0x20 )    # 0 0 1 0  0 0 0 0             n/a,  na, CLK11 = SYSREF, SCLK10_11_PD active, SCLK_DIS_MODE = 00, DCLK11_Norm_Polarity, DCLK11_No_Halfstep
        self._writeRegister(self.LMK, 0x12D , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x12E , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x12F , 0x60 )    # 0 1 0 1  0 0 0 0             CLK11 = LVPECL-2000mV, clk10_OFF  << This may Change to lower Amplitude: 0x40LVPECV-1600, 0x50=LVPECL-2000 0x60=LCPECL 
    
        # CLK12/13 GBTCLK2  and GBTCLK3 M2C LVDS both at 320MHz
        self._writeRegister(self.LMK, 0x130 , 0x0A )    # DIV_CLKOUT0 DIV_BY_10 = 320MHz 
        self._writeRegister(self.LMK, 0x131 , 0x00 )    # delay unused
        self._writeRegister(self.LMK, 0x132 , 0x70 )    # 0 1 1 1  0 0 0 0             CLKout0 active, Hi-perf_out, Hi-Perf_In, Dig_Delay_Powered_down, DCLK0_DIV8, 9 = 0 DCLK1_DIV8, 9 = 0
        self._writeRegister(self.LMK, 0x133 , 0x40 )    # 0 1 0 0      0 0 0 0         n/a, halfstep delay PD, CLK0 = DCLK, DCLK0 active, Dclk use divider, no_duty_cyc_cor, DCLK0_Norm_Polarity, DCLK0_No_Halfstep
        self._writeRegister(self.LMK, 0x134 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, na, CLK1 = DCLK,  DCLK1 active, SCLK_DIS_MODE = 00, DCLK1_Norm_Polarity, DCLK1_No_Halfstep
        self._writeRegister(self.LMK, 0x135 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, No_analog_Delay, 00000= analog delay
        self._writeRegister(self.LMK, 0x136 , 0x00 )    # 0 0 0 0  0 0 0 0             n/a, n/a, n/a, n/a, 0000 = digital delay 
        self._writeRegister(self.LMK, 0x137 , 0x11 )   # 0 0 0 1  0 0 0 1             LVDS, LVDS
    
        # the default mode uses the LMX2581 as a clock source so PLL1 must be disabled

        # Select VCO1 PLL1 source
        self._writeRegister(self.LMK, 0x138 , 0x40 )    # 0 1 0 0  0 0 0 0   CLKin1(externla VCO) Buf_osc_in, PowerDown 
        self._writeRegister(self.LMK, 0x139 , 0x03 )    # SYSREF_MUX, SYSREF_Free_Running_Output     SYSREF MUST BE initially ON (TBD) 
    
        # SYSREF Divider
        self._writeRegister(self.LMK, 0x13A , 0x01 )    # SYSREF_DIV(MS) SYSREF Divider    3200 / 320 = 10MHz
        self._writeRegister(self.LMK, 0x13B , 0x40 )    # SYSREF_DIV(LS) SYSREF Divider
    
        # SYSREF Digital Delay
        self._writeRegister(self.LMK, 0x13C , 0x00 )    # SYSREF_DDLY(MS) SYSREF Digital Delay  - Not Used
        self._writeRegister(self.LMK, 0x13D , 0x08 )    # SYSREF_DDLY(LS) SYSREF Digital Delay  - Not Used     
    
        self._writeRegister(self.LMK, 0x13E , 0x00 )    # SYSREF_PULSE_CNT 8 Pulses - Not Used
    
        # PLL2
        self._writeRegister(self.LMK, 0x13F , 0x00 )    # (defaults not used) FB_CTRL PLL2_FB=prescaler, PLL1_FB=OSCIN   This is default for internal Oscillator, this changes on EXT osc   
        self._writeRegister(self.LMK, 0x140 , 0xF1 )    # 1 1 1 1   0 0 0 0    PLL1_PD, VCO_LDO_PD, VCO_PD, OSCin_PD, All SYSREF Normal
        #if(rc!=self.UNITAPI_OK):     return rc;                                               // 0x01 default
        #try 0xf1
        self._writeRegister(self.LMK, 0x141 , 0x00 )    # Dynamic digital delay step = no adjust
        self._writeRegister(self.LMK, 0x142 , 0x00 )    # DIG_DLY_STEP_CNT No Adjustment of Digital Delay     
    
        self._writeRegister(self.LMK, 0x143 , 0x70 )    # SYNC_SYSREF SYNC functionality enabled, prevent SYNC pin and DLD flags from generating SYNC event
        #if(rc!=self.UNITAPI_OK)     return rc;                                               // DCLK12, DCLK10, DCLK8 do not re-sync during a sync event   ((*** SAME as 120 ***))??
        self._writeRegister(self.LMK, 0x144 , 0xFF )    # DISABLE_DCLK_SYNC Prevent SYSREF clocks from synchronizing     

        # new R counter sync function
        self._writeRegister(self.LMK, 0x145 , 0x00 )    # No Information yet and probably not applicable     
    
        self._writeRegister(self.LMK, 0x146 , 0x00 )    # CLKIN_SRC No AutoSwitching of clock inputs, all 3 CLKINx pins are set t0 Bipolar
    
        # fmc134 self.LMK Clock inputs are : clkin0 = trigger, clkin1 = LMX_OUT, clkin2 = off, OSCin = low frequency self.LMK, OSCout not used
        # Buffer LMX PLL as Clock Source
        if (clockmode == self.CLOCKTREE_CLKSRC_INTERNAL):                                                                                      
            self._writeRegister(self.LMK, 0x147 , 0x10 )  # 0 0 0 1  1 1 1 1  CLK_SEL_POL=hi, CLKIN_MUX_SEL= CLKIN_1 Manual = LMX2581E_ !INVERT, CLKIN1=Fin CLKIN0=SYSREF MUX
            print("Using LMX2581 PLL as Clock Source") 
                # !!!JOHN!!! explicitly clear ext_sample_clk_3p3 in CPLD !!!JOHN!!!


        self._writeRegister(self.LMK, 0x148 , 0x33 )    # CLKIN_SEL0_MUX Configured as self.LMK MISO Push Pull Output
        self._writeRegister(self.LMK, 0x149 , 0x00 )    # LKIN_SEL1=input     << Not used
        self._writeRegister(self.LMK, 0x14A , 0x00 )    #  RESET_MUX RESET Pin=Input Active High
        self._writeRegister(self.LMK, 0x14B , 0x02 )    # default      Disabled holdover DAC but leave at 0x200
        self._writeRegister(self.LMK, 0x14C , 0x00 )    #/ default      disabled but leave DAC at midscale 0x0200
        self._writeRegister(self.LMK, 0x14D , 0x00 )    #default      DAC_TRIP_LOW Min Voltage to force HOLDOVER
        self._writeRegister(self.LMK, 0x14E , 0x00 )    # default      DAC_TRIP_HIGH Mult=4 Max Voltage to force HOLDOVER
        self._writeRegister(self.LMK, 0x14F , 0x7F )    # default      DAC_UPDATE_CNTR
        self._writeRegister(self.LMK, 0x150 , 0x00 )    # default      HOLDOVER_SET HOLDOVER disable  << NEW Functionality
        self._writeRegister(self.LMK, 0x151 , 0x02 )    # default      HOLD_EXIT_COUNT(MS)
        self._writeRegister(self.LMK, 0x152 , 0x00 )    # default      HOLD_EXIT_COUNT(LS)
    
        #PLL1 CLKIN0 R Divider Not Used
        self._writeRegister(self.LMK, 0x153 , 0x00 )    #not used      CLKIN0_DIV (MS)
        self._writeRegister(self.LMK, 0x154 , 0x80 )    #not used      CLKIN0_DIV (LS)
    
        #PLL1 CLKIN1 R Divider Not Used 
        self._writeRegister(self.LMK, 0x155 , 0x00 )   # Not Used     CLKIN1_DIV (MS)     
        self._writeRegister(self.LMK, 0x156 , 0X80 )    # Not Used     CLKIN1_DIV (LS)   

        #PLL1 CLKIN2 R Divider not Used 
        self._writeRegister(self.LMK, 0x157 , 0x03 )    # Not Used     CLKIN2_DIV (MS) 
            
        self._writeRegister(self.LMK, 0x158 , 0xE8 )    # Not Used     CLKIN2_DIV (LS)      
    
        # This is part of a secondary configuration
        # LMX2581 Low frequency Output for use with self.LMK04832 VCO & PLL2, nominal frequency 500MHz 
        # configured for 100MHz reference to PLL2
        # PLL1 N divider, Divide 500MHz VCSO down to PDF
        self._writeRegister(self.LMK, 0x159 , 0x00 )    # PLL1_NDIV (MS)  PLL1 Ndivider = 5000 for 100HHz PDF    
        self._writeRegister(self.LMK, 0x15A , 0x05 )    # PLL1_NDIV (LS)       500MHz/5 = 100MHz PFD
    
        # PLL1 Configuration
        self._writeRegister(self.LMK, 0x15B , 0xF4 )    # PLL1 Pasive CPout1 tristate, Pos Slope, 50uA 
        self._writeRegister(self.LMK, 0x15C , 0x20 )    # Default not used 
        self._writeRegister(self.LMK, 0x15D , 0x00 )    # Default not used 
        self._writeRegister(self.LMK, 0x15E , 0x00 )    # default not used 
        self._writeRegister(self.LMK, 0x15F , 0x03 )    # Pasive Forced Logic Low Push_Pull 
    
        #      In the default usage PLL2 is pasivated
        # default mode is self.LMK provides a 400MHz reference clock and the PLL multiples it up to 3200? TBD 
        # PLL2 onfigured to lock VCO1 at 3000MHz to 500MHz from LMX with a PFD of 125MHz, (4N * 6P = 24) * 125MHz = 3000MHz
        # a prescale value of 6 allows the PLL2 N and R to match 
        self._writeRegister(self.LMK, 0x160 , 0x00 )    # PLL2_RDIV (MS) PLL2 Reference Divider = 4 refference frequency = 125MHz   
        self._writeRegister(self.LMK, 0x161 , 0x04 )    # PLL2_RDIV (LS)     
        self._writeRegister(self.LMK, 0x162 , 0xCC )    # D0 changed to 0xCC per new Migration doc
        self._writeRegister(self.LMK, 0x163 , 0x00 )    # PLL2_NCAL (HI) Only used during CAL
        self._writeRegister(self.LMK, 0x164 , 0x00 )    # PLL2_NCAL (MID)              
        self._writeRegister(self.LMK, 0x165 , 0x04 )    # PLL2_NCAL (LOW)
    
        # the following 5 writes are out of sequence per the TI programming sequence recomendations in the data sheet
        self._writeRegister(self.LMK, 0x145 , 0x00 )    # << Ignore, modify R divider Sync is needed
        self._writeRegister(self.LMK, 0x171 , 0xAA )    #     << Specified by TI
        self._writeRegister(self.LMK, 0x171 , 0x02 )   #      << Specified by TI
    
        self._writeRegister(self.LMK, 0x17C , 0x15 )    # OPT_REG1     **** VERIFY when new data sheet arives
        self._writeRegister(self.LMK, 0x17D , 0x33 )    # OPT_REG2     **** VERIFY when new data sheet arives
    
        self._writeRegister(self.LMK, 0x166 , 0x00 )    # PLL2_NDIV (HI) Allow CAL     
        self._writeRegister(self.LMK, 0x167 , 0x00 )    # PLL2_NDIV (MID) PLL2 N-Divider     
        self._writeRegister(self.LMK, 0x168 , 0x04 )    #      // PLL2_NDIV (LOW) Cal after writing this register     >>P = 3, N = 8  (24 * 125Mhz_ref = 3G)   
        self._writeRegister(self.LMK, 0x169 , 0x49 )    # PLL2_SETUP Window 3.7nS,  I(cp)=1.6mA, Pos Slope, CP ! Tristate, Bit 0 always 1  
        # 1.6mA gives better close in phase  noise than 3.2mA

        self._writeRegister(self.LMK, 0x16A , 0x00 )    # PLL2_LOCK_CNT (MS)      
        self._writeRegister(self.LMK, 0x16B , 0x20 )    # PLL2_LOCK_CNT (LS)  PD must be in lock for 16 cycles    
        self._writeRegister(self.LMK, 0x16C , 0x00 )   # PLL2_LOOP_FILTER_R Disable Internal Resistors        << Uses externla Loop Filter 
        # R3 = 200 Ohms  R4 = 200 Ohms

        self._writeRegister(self.LMK, 0x16D , 0x00 )    # PLL2_LOOP_FILTER_C Disable Internal Caps             << uses externla loop filter
        # C3 = 10pF  C4 = 10pF

        self._writeRegister(self.LMK, 0x16E , 0x12 )    # STATUS_LD2_MUX LD2=Locked   Push Pull Output
    
        # this disables PLL2
        if(1):
            self._writeRegister(self.LMK, 0x173 , 0x60 )   # 0 1 1 0 0 0 0 0  0x60 PLL2_Prescale_PD PLL2_PD 
            print("self.LMK PLL2 Powered Down") 

        # This Enables PLL2
        if(0):
            self._writeRegister(self.LMK, 0x173 , 0x00 )    # PLL2_MISC PLL2 Active, normal opperation  
            print("self.LMK PLL2 Active ") 
               

        time.sleep(0.1) # allow PLL to lock, not required in buffermode but does not hurt

        # Clear self.LMK PLL2 Erros regardless of if we use them
        self._writeRegister(self.LMK, 0x183, 0x01 ) 
        if(rc!=self.UNITAPI_OK):
            return rc
        self._writeRegister(self.LMK, 0x183, 0x00 ) 
        if(rc!=self.UNITAPI_OK):
            return rc

        # IF we are using self.LMK04832 PLL2 then wait500ms  to see if we ever go out of lock
        if (clockmode == self.CLOCKTREE_CLKSRC_INTERNAL ):
                time.sleep(0.5)          #     Look for half a sec to see if PLL is unlocked

                # verify self.LMK04832 PLL2 status
                dword = self._readRegister(self.LMK, 0x183) 
                print('dword = ',dword)
                if(rc!=self.UNITAPI_OK):
                    return rc

                if((dword&0x02)!=0x02):
                    print("PLL2 NOT locked, do something!!! \n")

                else:
                    print("PLL2 locked!!! \n")

        # try to sync all the output dividers
        # SYNC_MODE enable to SYNC event
        # SYSREF_CLR = 1
        # SYNC_1SHOT_EN = 1
        # SYNC_POL = 0 (Normal)
        # SYNC_EN = 1
        # SYNC_MODE = 1 (sync_event_generatedfrom SYNC pin)
        self._writeRegister(self.LMK, 0x143, 0xD1)

        # change SYSREF_MUX to normal SYNC (0)
        self._writeRegister(self.LMK,  0x139, 0x00)

        # Enable dividers reset
        self._writeRegister(self.LMK,  0x144, 0x00)

        #toggle the polarity (keep SYSREF_CLR active)
        self._writeRegister(self.LMK,  0x143, 0xF1)

        time.sleep(0.01)

        self._writeRegister(self.LMK, 0x143, 0xD1)
        # disable dividers
        self._writeRegister(self.LMK, 0x144, 0xFF)

        # change SYSREF_MUX back to continuous
        self._writeRegister(self.LMK, 0x139, 0x03)

        # restore SYNC_MODE & remove SYSREF_CLR
        self._writeRegister(self.LMK, 0x143, 0x50)
        print('default clktree init finished')

        return 0


    def internal_ref_and_lmx_enable(self, clockmode):
        rc = self.UNITAPI_OK
        # Read, Modify, Write to avoid clobbering any other register settings
        dword = self.proxy.readI2c(self.cpld_address + 2*4) # each cpld address is 4 byte long
        if(rc!=self.UNITAPI_OK):
            return rc

        if clockmode == self.CLOCKTREE_CLKSRC_INTERNAL:                         #Internal Reference
            # Set bits 3, 1, and 0
            dword |= 0xB
            self.proxy.writeI2c(self.cpld_address + 2*4,dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            #Read, Modify, Write to avoid clobbering any other register settings
            dword = self.proxy.readI2c(self.cpld_address + 1*4)
            print(' self.cpld_address + 1*4, dword = ',dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # configure the switch for the internal clock (CPLD address 1 bit 2)
            dword |= 1<<2
            self.proxy.writeI2c(self.cpld_address + 1*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

        elif clockmode == self.CLOCKTREE_CLKSRC_EXTERNAL:
            # turn off 0sc, ref switch and LMX enable0
            dword = 0xC4
            self.proxy.writeI2c(self.cpld_address + 2*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # Read, Modify, Write to avoid clobbering any other register settings
            dword = self.proxy.readI2c(self.cpld_address + 1*4)
            print(' self.cpld_address + 1*4, dword = ',dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # Clear bit 2
            dword &= 0xFB 
            self.proxy.writeI2c(self.cpld_address + 1*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

        elif clockmode == self.CLOCKTREE_REFSRC_EXTERNAL:         
            # turn off 0sc, point at ext ref enable LMX bits 3, 1, and 0
            dword = 0xCC
            self.proxy.writeI2c(self.cpld_address + 2*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # Read, Modify, Write to avoid clobbering any other register settings
            dword = self.proxy.readI2c(self.cpld_address + 1*4)
            print(' self.cpld_address + 1*4, dword = ',dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # set bit 2
            dword |= 0x04
            self.proxy.writeI2c(self.cpld_address + 1*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

        elif clockmode == self.CLOCKTREE_REFSRC_STACKED:         
            #turn ON 0sc, point at ext ref enable LMX bits 3, 1, and 0
            dword = 0xCD
            self.proxy.writeI2c(self.cpld_address + 2*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

            # Read, Modify, Write to avoid clobbering any other register settings
            dword = self.proxy.readI2c(self.cpld_address + 1*4)
            if(rc!=self.UNITAPI_OK):
                return rc

            # set bit 2    (Internal Sample Clock)
            dword |= 0x04
            self.proxy.writeI2c(self.cpld_address + 1*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc
        else:
            # Clear bits 3, 1, and 0
            dword &= 0xF4
            self.proxy.writeI2c(self.cpld_address + 2*4, dword)
            if(rc!=self.UNITAPI_OK):
                return rc

        return self.FMC134_CLOCKTREE_ERR_OK
    
    def reset_clock_chip(self):
        rc = self.UNITAPI_OK
        # #just to check
        # dword = 8
        # self.proxy.writeI2c(self.cpld_address + 1*4, dword)
        # Read, Modify, Write to avoid clobbering any other register settings
        dword = self.proxy.readI2c(self.cpld_address + 1*4)
        print('dword = self.proxy.readI2c(self.cpld_address + 1*4) ', dword)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Set reset bit
        dword |= 0x08
        self.proxy.writeI2c(self.cpld_address + 1*4, dword)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Clear reset bit
        dword &= 0xF7
        self.proxy.writeI2c(self.cpld_address + 1*4, dword)
        if(rc!=self.UNITAPI_OK):
            return rc

        return 0

    def default_adc_init(self,cmode, lDualChannel=False, inputCh='CHAN_A0_2'):
        print('start adc init')
        adc_txemphasis=0
        rc = self.UNITAPI_OK

        #////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        # ADC Initializaton


        # Set one byte per cycle
        # rc = unitapi_write_register(i2c_unit, I2C_BAR_CTRL+0x05, 0x00);
        # if(rc!=UNITAPI_OK)
        #         return rc;

        # Read, modify, write to avoid clobbering any other register settings
        dword0 = self.proxy.readI2c(self.cpld_address + 1*4)
        print(' self.cpld_address + 1*4, adc_init, dword0 = ',dword0)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Force a clear on the ADC0 Reset Pin
        dword0 &= 0xFC
        self.proxy.writeI2c(self.cpld_address + 1*4, dword0)
        if(rc!=self.UNITAPI_OK):
            return rc
            

        time.sleep(0.002)            

        # Reset part
        self._writeRegister(self.ADC_BOTH, 0x0000, 0xB0)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Set the D Clock  and SYSREF input pins to LVPECL
        self._writeRegister(self.ADC_BOTH, 0x002A, 0x06)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Set Timestamp input pins to LVPECL but do not enable timestamp
        self._writeRegister(self.ADC_BOTH, 0x003B, 0x02)
        if(rc!=self.UNITAPI_OK):
            return rc
            
        # Invert ADC0 Clock            (write to only ADC0)
        self._writeRegister(self.ADC0, 0x02B7, 0x01)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Enable SYSREF Processor
        self._writeRegister(self.ADC_BOTH, 0x0029, 0x20)
        if(rc!=self.UNITAPI_OK):
            return rc
        self._writeRegister(self.ADC_BOTH, 0x0029, 0x60)
        if(rc!=self.UNITAPI_OK):
            return rc

        #////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        # JESD Initializaton
        # Reset JESD during configuration
        self._writeRegister(self.ADC_BOTH, 0x0200, 0x00)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Clear Cal Enable AFTER clearing JESD Enable during configuration
        self._writeRegister(self.ADC_BOTH, 0x0061, 0x00)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Enable SYSREF Calibration while background calibration is disabled
        # Set 256 averages with 256 cycles per accumulation
        self._writeRegister(self.ADC_BOTH, 0x02B1, 0x0F)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Start SYSREF Calibration
        self._writeRegister(self.ADC_BOTH, 0x02B0, 0x01)
        if(rc!=self.UNITAPI_OK):
            return rc
            
        time.sleep(0.5)

        # Read SYSREF Calibration status
        dword0 = self._readRegister(self.ADC0, 0x02B4)

        if(rc!=self.UNITAPI_OK): 
            return rc

        if ((dword0 & 0x2) == 0x2):
            print("ADC0 SYSREF Calibration Done\n")
        else: 
            print("ADC0 SYSREF Calibration NOT Done!\n")
            return self.FMC134_ERR_ADC_INIT
        
        dword0 = self._readRegister(self.ADC1, 0x02B4)
        if(rc!=self.UNITAPI_OK):
            return rc

        if ((dword0 & 0x2) == 0x2):
            print("ADC1 SYSREF Calibration Done\n")
        else:
            print("ADC1 SYSREF Calibration NOT Done!\n")
            return self.FMC134_ERR_ADC_INIT

            
        if cmode == 'FG_CAL':
            # Set CAL_FG to enable foreground calibration
            self._writeRegister(self.ADC_BOTH, 0x0062, 0x01)
        elif cmode == 'BG_CAL':
            # Set CAL_BG to enable background calibration
            self._writeRegister(self.ADC_BOTH, 0x0062, 0x02)


        if(rc!=self.UNITAPI_OK):
            return rc

        # Set JMODE = 2 (or 0 for single channel mode)
        if (lDualChannel):
            self._writeRegister(self.ADC_BOTH, 0x0060, (0 if inputCh =='CHAN_A0_2' else 0x10)) 
            self._writeRegister(self.ADC_BOTH, 0x0201, 0x02)
            if(rc!=self.UNITAPI_OK):
                return rc
        else:
            self._writeRegister(self.ADC_BOTH, 0x0060, (1 if inputCh =='CHAN_A0_2' else 2)) 
            self._writeRegister(self.ADC_BOTH, 0x0201, 0x00)
            if(rc!=self.UNITAPI_OK):
                return rc
        

        # Set K = 16
        self._writeRegister(self.ADC_BOTH, 0x0202, 0x0F)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Keep output format as 2's complement and ENABLE Scrambler
        #spi_write(i2c_unit, ADC_SELECT_BOTH, 0x0204, 0x03);
        # Use binary offset output format and ENABLE Scrambler
        self._writeRegister(self.ADC_BOTH, 0x0204, 0x01)
        if(rc!=self.UNITAPI_OK):
            return rc
            
        if (cmode!='NO_CAL'):
            # Set Cal Enable BEFORE setting JESD Enable after configuration
            self._writeRegister(self.ADC_BOTH, 0x0061, 0x01)
        

        # Take JESD out of reset after configuration
        self._writeRegister(self.ADC_BOTH, 0x0200, 0x01)
        if(rc!=self.UNITAPI_OK):
            return rc


        # full scale range ** this setting directly affects the ADC SNR  **
        self._writeRegister(self.ADC_BOTH, 0x0030, 0xFF)        # NOTE this setting directly affects the ADC SNR
        if(rc!=self.UNITAPI_OK):
            return rc;                                                           # 0x0000 ~500mVp-p puts the max SNR at ~ 48.8dBFS
        self._writeRegister(self.ADC_BOTH, 0x0031, 0xFF)        # 0xA4C4 ~725mVp-p puts the max SNR at ~ 55.5dBFS (Default value at reset)
        if(rc!=self.UNITAPI_OK):
            return rc;                                                          # 0xFFFF ~950mVp-p puts the max SNR at ~ 56.5dBFS
        self._writeRegister(self.ADC_BOTH, 0x0032, 0xFF)
        if(rc!=self.UNITAPI_OK):
            return rc
        self._writeRegister(self.ADC_BOTH, 0x0033, 0xFF)
        if(rc!=self.UNITAPI_OK):
            return rc

        # verify ADC1 is present, This verifys the SPI connection to ADC 1 is present
        dw = [0 for i in range(4)]

        for i in range(4):
            dw[i] = self._readRegister( self.ADC0, 0x0030+i) 
        print("Read FS_RANGE_0: %x %x %x %x\n",
                    dw[0], dw[1], dw[2], dw[3])

        for i in range(4):
            dw[i] = self._readRegister( self.ADC1, 0x0030+i) 
        print("Read FS_RANGE_1: %x %x %x %x\n",
                    dw[0], dw[1], dw[2], dw[3])


        if (cmode=='FG_CAL'):
            # Dump trim registers
            # adc_cal_dump(0);
            # adc_cal_dump(1);

            self._writeRegister(self.ADC_BOTH, 0x006C, 0x00) # trigger
            dword0 = self._readRegister( self.ADC0, 0x006C)
            print("CAL_TRIG 0x%x\n",dword0)
            self._writeRegister(self.ADC_BOTH, 0x006C, 0x01) # trigger
            dword0 = self._readRegister(  self.ADC0, 0x006C)
            print("CAL_TRIG 0x%x\n",dword0)
            for ch in range(2):
                adcsel = (self.ADC0 if ch==0 else self.ADC1)
                for i in range(100):
                    time.sleep(0.5)
                    # Read CAL status
                    dword0 = self._readRegister( adcsel, 0x006A)
                    if(rc!=self.UNITAPI_OK):
                        return rc
                    if ((dword0 & 0x1) == 0x1):
                        print("ADC%d FG Calibration Done\n",ch)
                        break
                    
                    else:
                        print("ADC%d FG Calibration NOT Done! [%x]\n",ch,dword0)
                    
                
                if ((dword0 & 0x1) == 0):
                    return self.FMC134_ERR_ADC_INIT


        # adc_cal_load(0, calib_adc0);
        # adc_cal_load(1, calib_adc1);

        # # Dump trim registers
        # calib_adc0 = adc_cal_dump(0);
        # logging::info("Calib[0]: %s\n",calib_adc0.c_str());

        # calib_adc1 = adc_cal_dump(1);
        # logging::info("Calib[1]: %s\n",calib_adc1.c_str());

        time.sleep(0.005)

        # Configure the transceiver pre-emphasis setting (0 to 0xF)
        self._writeRegister(self.ADC_BOTH, 0x0048, adc_txemphasis)
        if(rc!=self.UNITAPI_OK):
            return rc

        # Disable SYSREF Processor in ADC before turning off SYSREF outputs
        self._writeRegister(self.ADC_BOTH, 0x0029, 0x00)
        if(rc!=self.UNITAPI_OK):
            return rc

        self._writeRegister(self.LMK, 0x12F , 0x00 )    # Disable Sysref to ADC 0
        if(rc!=self.UNITAPI_OK):
            return rc
        self._writeRegister( self.LMK, 0x117 , 0x00 )    # Disable Sysref to ADC 1
        if(rc!=self.UNITAPI_OK):
            return rc

        print("*** default_adc_init done ***")

        return self.FMC134_ADC_ERR_OK
    
             
    # def reset_clock_chip(self):
    #     dword = 0
    #     rc = self.UNITAPI_OK

    #     # Read, Modify, Write to avoid clobbering any other register settings
    #     dword0 = self.proxy.readI2c( self.cpld_address + 1*4, dword)
    #     if(rc!=self.UNITAPI_OK):
    #         return rc

    #     # Set reset bit
    #     dword |= 0x08
    #     self.proxy.writeI2c( self.cpld_address + 1*4, dword)
    #     if(rc!=self.UNITAPI_OK):
    #         return rc

    #     # Clear reset bit
    #     dword &= 0xF7
    #     self.proxy.writeI2c( self.cpld_address + 1*4, dword)
    #     if(rc!=self.UNITAPI_OK):
    #         return rc

    #     return 0

class I2cMux(object):
    def __init__(self,proxy,offset):
        self.proxy  = proxy
        self.offset = offset

    def setPort(self, arg):
        self.proxy.writeI2c(self.offset,arg)


class I2c134(pr.Device):
    def __init__(   self,
            name        = "AdcConfig",
            description = "Set configuration",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        # I2CProxy
        self.add(AxiLiteMasterProxy(
            name   = "MasterProxy",
            offset = 0x0000_8000,
            expand = False ))

        self.i2cmux       = I2cMux  (self.MasterProxy,0x0000)
        self.fmcCpld       = FmcCpld (self.MasterProxy,0x2800)
        @self.command(value='')
        def set_134_clk(arg):
            self.i2cmux.setPort(i2cSwitchPort[arg])
            self.fmcCpld.default_clocktree_init(1)
        @self.command(value='')
        def set_134_adc(arg):
            self.i2cmux.setPort(i2cSwitchPort[arg])
            self.fmcCpld.default_adc_init(cmode = 'FG_CAL')