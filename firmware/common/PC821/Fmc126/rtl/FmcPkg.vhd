library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;

library surf;
use surf.StdRtlPkg.all;
use surf.I2cPkg.all;

package FmcPkg is

  constant ROW_SIZE : integer := 8;
  constant ROW_IDXB : integer := bitSize(ROW_SIZE);

  subtype AdcWord is slv(10 downto 0);
  type AdcWordArray is array(natural range<>) of AdcWord;
  
  constant DEVICE_MAP_C : I2cAxiLiteDevArray(12 downto 0) := (
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
    --  FMC SPI Bridge [1B addressing, 1B payload]
--     7 => MakeI2cAxiLiteDevType( "0101001", 8, 8, '0' ),
    --  FMC SPI Bridge [1B addressing, 1B payload]
--     8 => MakeI2cAxiLiteDevType( "0101010", 8, 8, '0' ),
    --  FMC SPI Bridge [1B addressing, 1B payload]
--     9 => MakeI2cAxiLiteDevType( "0101011", 8, 8, '0' )
    --  ADT7411 Voltage/Temp Mon FMC
    8 => MakeI2cAxiLiteDevType( "1001000", 8, 8, '0' ),
    --  FMC SPI Bridge configuration
    9 => MakeI2cAxiLiteDevType( "0101000", 8, 8, '0' ),
    --  FMC SPI Bridge [1B addressing, 1B payload]
    10 => MakeI2cAxiLiteDevType( "0101000",16, 8, '0' ),
    --  FMC SPI Bridge [2B addressing, 1B payload]
    11 => MakeI2cAxiLiteDevType( "0101000",24, 8, '0' ),
    --  FMC EEPROM
    12 => MakeI2cAxiLiteDevType( "1010000",8, 8, '0' )
    );                                                        

  
end FmcPkg;

package body FmcPkg is
end package body FmcPkg;

