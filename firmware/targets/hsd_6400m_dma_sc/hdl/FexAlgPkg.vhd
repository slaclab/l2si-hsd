
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package FexAlgPkg is

  type StringArray is array(natural range<>) of string(1 to 3);
  type StringMatrix is array(natural range<>) of StringArray(0 to 3);
  
  constant FEX_ALGORITHMS : StringArray(0 to 3) := ("NCH","NCH","NTR","NAF");
  constant RAM_DEPTH_C : integer := 2048;
  
end FexAlgPkg;
