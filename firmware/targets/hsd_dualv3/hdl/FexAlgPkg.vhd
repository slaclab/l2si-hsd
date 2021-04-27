
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package FexAlgPkg is

  type StringArray is array(natural range<>) of string(1 to 3);

  constant FEX_ALGORITHMS : StringArray(0 to 4) := ("CHN","CHN","CHN","CHN","NAF");
  
end FexAlgPkg;
