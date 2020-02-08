-------------------------------------------------------------------------------
-- File       : AxiI2cRegMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2019-02-07
-------------------------------------------------------------------------------
-- Description: AXI-Lite I2C Register Master
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiI2cRegMaster is
   generic (
      TPD_G            : time               := 1 ns;
      DEVICE_MAP_G     : I2cAxiLiteDevArray;
      I2C_SCL_FREQ_G   : real               := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G  : real               := 100.0E-9;   -- units of seconds
      AXI_CLK_FREQ_G   : real               := 156.25E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0)    := AXI_RESP_SLVERR_C);
   port (
      -- I2C Ports
      scl            : inout sl;
      sda            : inout sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiI2cRegMaster;

architecture mapping of AxiI2cRegMaster is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   constant DEBUG_C : boolean := false;

   signal dbgclk : sl := '0';
   component ila_0
     port ( clk   : in sl;
            probe0 : in slv(255 downto 0) );
   end component;
begin

   GEN_DEBUG : if DEBUG_C generate
     process (axiClk) is
       variable count : slv(4 downto 0);
     begin
       if rising_edge(axiClk) then
         if (count = toSlv(31,5)) then
           dbgclk <= not dbgclk;
           count := (others=>'0');
         else
           count := count + 1;
         end if;
       end if;
     end process;
     U_ILA : ila_0
       port map ( clk       => dbgclk,
                  probe0(0) => i2ci.scl,
                  probe0(1) => i2ci.sda,
                  probe0(255 downto 2) => (others=>'0') );
   end generate;

   I2cRegMasterAxiBridge_Inst : entity surf.I2cRegMasterAxiBridge
      generic map (
         TPD_G            => TPD_G,
         DEVICE_MAP_G     => DEVICE_MAP_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- I2C Register Interface
         i2cRegMasterIn  => i2cRegMasterIn,
         i2cRegMasterOut => i2cRegMasterOut,
         -- AXI-Lite Register Interface
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         -- Clocks and Resets
         axiClk          => axiClk,
         axiRst          => axiRst);

   I2cRegMaster_Inst : entity surf.I2cRegMaster
      generic map(
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         PRESCALE_G           => PRESCALE_C)
      port map (
         -- I2C Port Interface
         i2ci   => i2ci,
         i2co   => i2co,
         -- I2C Register Interface
         regIn  => i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         -- Clock and Reset
         clk    => axiClk,
         srst   => axiRst);

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output  

end mapping;
