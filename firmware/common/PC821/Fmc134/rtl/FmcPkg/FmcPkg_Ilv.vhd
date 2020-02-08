library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;

library surf;
use surf.StdRtlPkg.all;
use surf.I2cPkg.all;

package FmcPkg is

  constant ROW_SIZE : integer := 10;
  constant ROW_IDXB : integer := bitSize(ROW_SIZE);

  subtype AdcWord is slv(11 downto 0);
  type AdcWordArray is array(natural range<>) of AdcWord;
  
  constant DEVICE_MAP_C : I2cAxiLiteDevArray(11 downto 0) := (
    -----------------------
    -- PC821 I2C DEVICES --
    -----------------------
    -- PCA9548A I2C Mux
    0 => MakeI2cAxiLiteDevType( "1110100", 8, 0, '0' ),
    -- SI5338 Local clock synthesizer
    1 => MakeI2cAxiLiteDevType( "1110001", 8, 8, '0' ),
    -- Local CPLD
    2 => MakeI2cAxiLiteDevType( "1100000", 8, 8, '0' ),
    -- ADT7411 Voltage/Temp Mon 1
    3 => MakeI2cAxiLiteDevType( "1001000", 8, 8, '0' ),
    -- ADT7411 Voltage/Temp Mon 2
    4 => MakeI2cAxiLiteDevType( "1001010", 8, 8, '0' ),
    -- ADT7411 Voltage/Temp Mon 3
    5 => MakeI2cAxiLiteDevType( "1001011", 8, 8, '0' ),
    --  TPS2481 Current Mon 1
    6 => MakeI2cAxiLiteDevType( "1000000", 16, 8, '1' ),
    --  TPS2481 Current Mon 2
    7 => MakeI2cAxiLiteDevType( "1000001", 16, 8, '1' ),
    -----------------------
    -- FMC134 I2C DEVICES --
    -----------------------
    --  FMC AD7291 Mon ADC
    8 => MakeI2cAxiLiteDevType( "0101111", 8, 8, '0' ),
    --  FMC AD7291 Mon Voltage
    9 => MakeI2cAxiLiteDevType( "0101110", 8, 8, '0' ),
    --  FMC CPLD
    10 => MakeI2cAxiLiteDevType( "0011100", 8, 8, '0' ),
    --  FMC EEPROM
    11 => MakeI2cAxiLiteDevType( "1010000",8, 8, '0' )
    );

  component jesd204b_16lane is
    port (
      rx_rst           : in  std_logic;
      sysref           : in  std_logic;
      rx_clk_out       : in  std_logic;
      scrambling_en    : in  std_logic;
      f_align_char     : in  std_logic_vector(7 downto 0);
      k_lmfc_cnt       : in  std_logic_vector(4 downto 0);

      -- ADC Interface
      adc_data0        : out std_logic_vector(255 downto 0);
      adc_data1        : out std_logic_vector(255 downto 0);
      adc_data2        : out std_logic_vector(255 downto 0);
      adc_data3        : out std_logic_vector(255 downto 0);
      adc_valid0       : out std_logic;
      adc_valid1       : out std_logic;
      adc_valid2       : out std_logic;
      adc_valid3       : out std_logic;

      -- Transceiver RX Interface
      rx_data_out0     : in  std_logic_vector(63 downto 0);
      rx_data_out1     : in  std_logic_vector(63 downto 0);
      rx_data_out2     : in  std_logic_vector(63 downto 0);
      rx_data_out3     : in  std_logic_vector(63 downto 0);
      rx_data_out4     : in  std_logic_vector(63 downto 0);
      rx_data_out5     : in  std_logic_vector(63 downto 0);
      rx_data_out6     : in  std_logic_vector(63 downto 0);
      rx_data_out7     : in  std_logic_vector(63 downto 0);
      rx_data_out8     : in  std_logic_vector(63 downto 0);
      rx_data_out9     : in  std_logic_vector(63 downto 0);
      rx_data_out10    : in  std_logic_vector(63 downto 0);
      rx_data_out11    : in  std_logic_vector(63 downto 0);
      rx_data_out12    : in  std_logic_vector(63 downto 0);
      rx_data_out13    : in  std_logic_vector(63 downto 0);
      rx_data_out14    : in  std_logic_vector(63 downto 0);
      rx_data_out15    : in  std_logic_vector(63 downto 0);
      rx_kchar_out0    : in  std_logic_vector(7 downto 0);
      rx_kchar_out1    : in  std_logic_vector(7 downto 0);
      rx_kchar_out2    : in  std_logic_vector(7 downto 0);
      rx_kchar_out3    : in  std_logic_vector(7 downto 0);
      rx_kchar_out4    : in  std_logic_vector(7 downto 0);
      rx_kchar_out5    : in  std_logic_vector(7 downto 0);
      rx_kchar_out6    : in  std_logic_vector(7 downto 0);
      rx_kchar_out7    : in  std_logic_vector(7 downto 0);
      rx_kchar_out8    : in  std_logic_vector(7 downto 0);
      rx_kchar_out9    : in  std_logic_vector(7 downto 0);
      rx_kchar_out10   : in  std_logic_vector(7 downto 0);
      rx_kchar_out11   : in  std_logic_vector(7 downto 0);
      rx_kchar_out12   : in  std_logic_vector(7 downto 0);
      rx_kchar_out13   : in  std_logic_vector(7 downto 0);
      rx_kchar_out14   : in  std_logic_vector(7 downto 0);
      rx_kchar_out15   : in  std_logic_vector(7 downto 0);
      rx_dispar_out0   : in  std_logic_vector(7 downto 0);
      rx_dispar_out1   : in  std_logic_vector(7 downto 0);
      rx_dispar_out2   : in  std_logic_vector(7 downto 0);
      rx_dispar_out3   : in  std_logic_vector(7 downto 0);
      rx_dispar_out4   : in  std_logic_vector(7 downto 0);
      rx_dispar_out5   : in  std_logic_vector(7 downto 0);
      rx_dispar_out6   : in  std_logic_vector(7 downto 0);
      rx_dispar_out7   : in  std_logic_vector(7 downto 0);
      rx_dispar_out8   : in  std_logic_vector(7 downto 0);
      rx_dispar_out9   : in  std_logic_vector(7 downto 0);
      rx_dispar_out10  : in  std_logic_vector(7 downto 0);
      rx_dispar_out11  : in  std_logic_vector(7 downto 0);
      rx_dispar_out12  : in  std_logic_vector(7 downto 0);
      rx_dispar_out13  : in  std_logic_vector(7 downto 0);
      rx_dispar_out14  : in  std_logic_vector(7 downto 0);
      rx_dispar_out15  : in  std_logic_vector(7 downto 0);
      rx_invalid_out0  : in  std_logic_vector(7 downto 0);
      rx_invalid_out1  : in  std_logic_vector(7 downto 0);
      rx_invalid_out2  : in  std_logic_vector(7 downto 0);
      rx_invalid_out3  : in  std_logic_vector(7 downto 0);
      rx_invalid_out4  : in  std_logic_vector(7 downto 0);
      rx_invalid_out5  : in  std_logic_vector(7 downto 0);
      rx_invalid_out6  : in  std_logic_vector(7 downto 0);
      rx_invalid_out7  : in  std_logic_vector(7 downto 0);
      rx_invalid_out8  : in  std_logic_vector(7 downto 0);
      rx_invalid_out9  : in  std_logic_vector(7 downto 0);
      rx_invalid_out10 : in  std_logic_vector(7 downto 0);
      rx_invalid_out11 : in  std_logic_vector(7 downto 0);
      rx_invalid_out12 : in  std_logic_vector(7 downto 0);
      rx_invalid_out13 : in  std_logic_vector(7 downto 0);
      rx_invalid_out14 : in  std_logic_vector(7 downto 0);
      rx_invalid_out15 : in  std_logic_vector(7 downto 0);
      adc_syncb        : out std_logic_vector(1 downto 0)
      );
  end component jesd204b_16lane;

end FmcPkg;

package body FmcPkg is
end package body FmcPkg;

