-------------------------------------------------------------------------------
-- File       : hsd_6400m_dma_nc_115.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI PCIe Core for Xilinx KCU105 board (PCIe GEN3 x 8 lanes)
-- https://www.xilinx.com/products/boards-and-kits/kcu105.html
-------------------------------------------------------------------------------
-- This file is part of 'axi-pcie-core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'axi-pcie-core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
 
library surf;
use surf.StdRtlPkg.all;

library work;

library xil_defaultlib;
use xil_defaultlib.types_pkg.all;

entity hsd_6400m_dma_nc_115 is
  generic (
    BUILD_INFO_G  : BuildInfoType );
  port (
    -- PC821 Interface
    cpld_fpga_bus    : inout slv(8 downto 0);
    cpld_eeprom_wp   : out   sl;
    --
    flash_noe        : out   sl;
    flash_nwe        : out   sl;
    flash_address    : out   slv(25 downto 0);
    flash_data       : inout slv(15 downto 0);
    -- I2C
    scl            : inout sl;
    sda            : inout sl;
    -- Timing
    timingRefClkP  : in  sl;
    timingRefClkN  : in  sl;
    timingRxP      : in  sl;
    timingRxN      : in  sl;
    timingTxP      : out sl;
    timingTxN      : out sl;
    timingModAbs   : in  sl;
    timingRxLos    : in  sl;
    timingTxDis    : out sl;
    -- PCIe Ports 
    pciRstL        : in    sl;
    pciRefClkP     : in    sl;
    pciRefClkN     : in    sl;
    pciRxP         : in    slv(7 downto 0);
    pciRxN         : in    slv(7 downto 0);
    pciTxP         : out   slv(7 downto 0);
    pciTxN         : out   slv(7 downto 0);

    oe_osc     : out   sl;

    -- ADC Interface
    lmk_out_p      : in    slv(3 downto 2);
    lmk_out_n      : in    slv(3 downto 2);

    pllRefClk      : out   sl;
    
    ext_trigger_p    : in    sl;
    ext_trigger_n    : in    sl;
    
    sync_to_lmk      : out   sl;

    adc_refclka_p    : in    slv(1 downto 0);
    adc_refclka_n    : in    slv(1 downto 0);
    adc_refclkb_p    : in    slv(1 downto 0);
    adc_refclkb_n    : in    slv(1 downto 0);
    
    adc_da_p         : in    Slv4Array(1 downto 0);
    adc_da_n         : in    Slv4Array(1 downto 0);
    adc_db_p         : in    Slv4Array(1 downto 0);
    adc_db_n         : in    Slv4Array(1 downto 0);
    
    adc_ora          : in    Slv2Array(1 downto 0);
    adc_orb          : in    Slv2Array(1 downto 0);
    adc_ncoa         : out   Slv2Array(1 downto 0);
    adc_ncob         : out   Slv2Array(1 downto 0);
    adc_syncse_n     : out   slv      (1 downto 0);
    adc_calstat      : in    slv      (1 downto 0);

    --
    pg_m2c           : in    slv      (1 downto 0);
    prsnt_m2c_l      : in    slv      (1 downto 0) );
end hsd_6400m_dma_nc_115;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture top_level of hsd_6400m_dma_nc_115 is
begin
  U_Top : entity work.AbacoPC820Top
    generic map (
      BUILD_INFO_G  => BUILD_INFO_G,
      TIMING_CORE_G => "LCLSI" )
    port map (
      -- PC821 Interface
      cpld_fpga_bus  => cpld_fpga_bus,
      cpld_eeprom_wp => cpld_eeprom_wp,
      --
      flash_noe      => flash_noe,
      flash_nwe      => flash_nwe,
      flash_address  => flash_address,
      flash_data     => flash_data,
      -- I2C
      scl            => scl,
      sda            => sda,
      -- Timing
      timingRefClkP  => timingRefClkP,
      timingRefClkN  => timingRefClkN,
      timingRxP      => timingRxP,
      timingRxN      => timingRxN,
      timingTxP      => timingTxP,
      timingTxN      => timingTxN,
      timingModAbs   => timingModAbs,
      timingRxLos    => timingRxLos,
      timingTxDis    => timingTxDis,
      -- PCIe Ports 
      pciRstL        => pciRstL,
      pciRefClkP     => pciRefClkP,
      pciRefClkN     => pciRefClkN,
      pciRxP         => pciRxP,
      pciRxN         => pciRxN,
      pciTxP         => pciTxP,
      pciTxN         => pciTxN,
      oe_osc         => oe_osc,
      -- ADC Interface
      lmk_out_p      => lmk_out_p,
      lmk_out_n      => lmk_out_n,
      pllRefClk      => pllRefClk,
      ext_trigger_p  => ext_trigger_p,
      ext_trigger_n  => ext_trigger_n,    
      sync_to_lmk    => sync_to_lmk,

      adc_refclka_p  => adc_refclka_p,
      adc_refclka_n  => adc_refclka_n,
      adc_refclkb_p  => adc_refclkb_p,
      adc_refclkb_n  => adc_refclkb_n,
      
      adc_da_p       => adc_da_p,
      adc_da_n       => adc_da_n,
      adc_db_p       => adc_db_p,
      adc_db_n       => adc_db_n,
      
      adc_ora        => adc_ora,
      adc_orb        => adc_orb,
      adc_ncoa       => adc_ncoa,
      adc_ncob       => adc_ncob,
      adc_syncse_n   => adc_syncse_n,
      adc_calstat    => adc_calstat,
      --
      pg_m2c         => pg_m2c,
      prsnt_m2c_l    => prsnt_m2c_l );
end top_level;
