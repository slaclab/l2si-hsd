library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

package AxiPcieRegPkg is

  constant FLS_ADDR_C : slv(31 downto 0) := x"0008_0000";
  constant XVC_ADDR_C : slv(31 downto 0) := x"0009_0000";
  constant I2C_ADDR_C : slv(31 downto 0) := x"000A_0000";
  constant GTH_ADDR_C : slv(31 downto 0) := x"000B_0000";
  constant TIM_ADDR_C : slv(31 downto 0) := x"000C_0000";
  constant APP_ADDR_C : slv(31 downto 0) := x"0010_0000";

end AxiPcieRegPkg;

package body AxiPcieRegPkg is
end package body AxiPcieRegPkg;

