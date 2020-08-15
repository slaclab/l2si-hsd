---------------
-- Title : top project 
-- Project : quad_demo
-------------------------------------------------------------------------------
-- File : quad_demo_top.vhd
-- Author : FARCY G.
-- Compagny : e2v
-- Last update : 2009/05/07
-- Plateform :  
-------------------------------------------------------------------------------
-- Description : link all project blocks
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- library description
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
 
library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;

library axi_pcie_core;
use axi_pcie_core.AxiPcieRegPkg.all;

library work;
use work.QuadAdcPkg.all;
use work.FmcPkg.all;

library unisim;            
use unisim.vcomponents.all;  
-------------------------------------------------------------------------------
-- Configuration IODELAY on data
-- VERSION_625MHz = TRUE    no iodelay
-- VERSION_625MHz = FALSE   iodelay

-------------------------------------------------------------------------------
entity hsd_dualv3 is
  generic (
    BUILD_INFO_G : BuildInfoType );
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
    -- ADC Interface
    fmc_to_cpld      : inout Slv4Array(1 downto 0);
    front_io_fmc     : inout Slv4Array(1 downto 0);
    --
    clk_to_fpga_p    : in    slv(1 downto 0);
    clk_to_fpga_n    : in    slv(1 downto 0);
    ext_trigger_p    : in    slv(1 downto 0);
    ext_trigger_n    : in    slv(1 downto 0);
    sync_from_fpga_p : out   slv(1 downto 0);
    sync_from_fpga_n : out   slv(1 downto 0);
    --
    adr_p            : in    slv(1 downto 0);              -- serdes clk
    adr_n            : in    slv(1 downto 0);
    ad_p             : in    Slv10Array(1 downto 0);
    ad_n             : in    Slv10Array(1 downto 0);
    aor_p            : in    slv(1 downto 0);              -- out-of-range
    aor_n            : in    slv(1 downto 0);
    --
    bdr_p            : in    slv(1 downto 0);
    bdr_n            : in    slv(1 downto 0);
    bd_p             : in    Slv10Array(1 downto 0);
    bd_n             : in    Slv10Array(1 downto 0);
    bor_p            : in    slv(1 downto 0);
    bor_n            : in    slv(1 downto 0);
    --
    cdr_p            : in    slv(1 downto 0);
    cdr_n            : in    slv(1 downto 0);
    cd_p             : in    Slv10Array(1 downto 0);
    cd_n             : in    Slv10Array(1 downto 0);
    cor_p            : in    slv(1 downto 0);
    cor_n            : in    slv(1 downto 0);
    --
    ddr_p            : in    slv(1 downto 0);
    ddr_n            : in    slv(1 downto 0);
    dd_p             : in    Slv10Array(1 downto 0);
    dd_n             : in    Slv10Array(1 downto 0);
    dor_p            : in    slv(1 downto 0);
    dor_n            : in    slv(1 downto 0);
    --
    pg_m2c           : in    slv(1 downto 0);
    prsnt_m2c_l      : in    slv(1 downto 0) );
end hsd_dualv3;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of hsd_dualv3 is

  --  Set timing specific clock parameters
  constant LCLSII_C : boolean := false;
--  constant LCLSII_C : boolean := true;
  constant NFMC_C   : integer := 2;
  constant DMA_SIZE_C : integer := NFMC_C;
  
  signal regReadMaster  : AxiLiteReadMasterType;
  signal regReadSlave   : AxiLiteReadSlaveType;
  signal regWriteMaster : AxiLiteWriteMasterType;
  signal regWriteSlave  : AxiLiteWriteSlaveType;
  signal sysClk, sysRst : sl;
  signal dmaClk, dmaRst : sl;
  signal regClk, regRst : sl;
  signal tmpReg         : Slv32Array(0 downto 0);

  constant NUM_AXI_MASTERS_C : integer := 2;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(2, x"00080000", 19, 16);
  signal axilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal axilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
  signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal axilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);

  signal timingRefClk     : sl;
  signal timingRefClkCopy : sl;
  signal timingRefClkGt   : sl;
  signal timingRecClk   : sl;
  signal timingRecClkRst: sl;
  signal timingBus      : TimingBusType;

  signal dmaIbMaster    : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0);
  signal dmaIbSlave     : AxiStreamSlaveArray (DMA_SIZE_C-1 downto 0);
  
  constant DMA_AXIS_CONFIG_C : AxiStreamConfigType := (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 32,
     TDEST_BITS_C  => 0,
     TID_BITS_C    => 0,
     TKEEP_MODE_C  => TKEEP_NORMAL_C,
     TUSER_BITS_C  => 0,
     TUSER_MODE_C  => TUSER_NORMAL_C );

  constant SIM_TIMING : boolean := false;
  
  signal tpgData           : TimingRxType := TIMING_RX_INIT_C;
  signal readoutReady      : sl;

  signal adcInput : AdcInputArray(4*NFMC_C-1 downto 0);
  
  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0));
  end component;
-------------------------------------------------------------------------------
-- architecture begin
-------------------------------------------------------------------------------
begin  -- rtl

  timingTxDis <= '0';
  
  ---------------
  -- Timing
  ---------------   
  TIMING_REFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
    generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",
      REFCLK_ICNTL_RX    => "00")
    port map (
      I     => timingRefClkP,
      IB    => timingRefClkN,
      CEB   => '0',
      ODIV2 => timingRefClkCopy,
      O     => timingRefClkGt);

  U_BUFG_T : BUFG_GT
    port map (
      I       => timingRefClkCopy,
      CE      => '1',
      CEMASK  => '1',
      CLR     => '0',
      CLRMASK => '1',
      DIV     => "000",
      O       => timingRefClk);
  
  U_Core : entity work.AbacoPC820Core
    generic map ( DMA_SIZE_G           => DMA_SIZE_C,
                  DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_C,
                  BUILD_INFO_G         => BUILD_INFO_G,
                  DEVICE_MAP_G         => DEVICE_MAP_C,
                  TIMING_CORE_G        => "LCLSI" )
   port map (  -- DMA Interfaces
               dmaClk         => dmaClk,
               dmaRst         => dmaRst,
               dmaObMasters   => open,
               dmaObSlaves    => (others=>AXI_STREAM_SLAVE_INIT_C),
               dmaIbMasters   => dmaIbMaster,
               dmaIbSlaves    => dmaIbSlave,
               -- Application AXI-Lite
               appClk         => regClk,
               appRst         => regRst,
               appReadMaster  => regReadMaster,
               appReadSlave   => regReadSlave,
               appWriteMaster => regWriteMaster,
               appWriteSlave  => regWriteSlave,
               -- Boot Memory Ports
               flashAddr      => flash_address,
               flashData      => flash_data,
               flashOe_n      => flash_noe,
               flashWe_n      => flash_nwe,
               -- I2C
               scl            => scl,
               sda            => sda,
               -- Timing
               timingRefClk   => timingRefClk,
               timingRxP      => timingRxP,
               timingRxN      => timingRxN,
               timingTxP      => timingTxP,
               timingTxN      => timingTxN,
               timingRecClk   => timingRecClk,
               timingRecClkRst=> timingRecClkRst,
               timingBus      => timingBus,
               timingFb       => TIMING_PHY_INIT_C,
               -- PCIE Ports
               pciRstL        => pciRstL,
               pciRefClkP     => pciRefClkP,
               pciRefClkN     => pciRefClkN,
               pciRxP         => pciRxP,
               pciRxN         => pciRxN,
               pciTxP         => pciTxP,
               pciTxN         => pciTxN );

    --------------------------
  -- AXI-Lite: Crossbar Core
  --------------------------
  U_XBAR : entity surf.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => regClk,
      axiClkRst        => regRst,
      sAxiWriteMasters(0) => regWriteMaster,
      sAxiWriteSlaves (0) => regWriteSlave,
      sAxiReadMasters (0) => regReadMaster,
      sAxiReadSlaves  (0) => regReadSlave,
      mAxiWriteMasters => axilWriteMasters,
      mAxiWriteSlaves  => axilWriteSlaves,
      mAxiReadMasters  => axilReadMasters,
      mAxiReadSlaves   => axilReadSlaves);

  GEN_ADCINP : for i in 0 to NFMC_C-1 generate
    adcInput(0+4*i).clkp <= adr_p(i);
    adcInput(0+4*i).clkn <= adr_n(i);
    adcInput(0+4*i).datap <= aor_p(i) & ad_p(i);
    adcInput(0+4*i).datan <= aor_n(i) & ad_n(i);
    adcInput(1+4*i).clkp <= bdr_p(i);
    adcInput(1+4*i).clkn <= bdr_n(i);
    adcInput(1+4*i).datap <= bor_p(i) & bd_p(i);
    adcInput(1+4*i).datan <= bor_n(i) & bd_n(i);
    adcInput(2+4*i).clkp <= cdr_p(i);
    adcInput(2+4*i).clkn <= cdr_n(i);
    adcInput(2+4*i).datap <= cor_p(i) & cd_p(i);
    adcInput(2+4*i).datan <= cor_n(i) & cd_n(i);
    adcInput(3+4*i).clkp <= ddr_p(i);
    adcInput(3+4*i).clkn <= ddr_n(i);
    adcInput(3+4*i).datap <= dor_p(i) & dd_p(i);
    adcInput(3+4*i).datan <= dor_n(i) & dd_n(i);
  end generate;
  
  U_APP : entity work.Application
    generic map ( LCLSII_G            => LCLSII_C,
                  BASE_ADDR_G         => APP_ADDR_C,
                  DMA_SIZE_G          => DMA_SIZE_C,
                  DMA_STREAM_CONFIG_G => DMA_AXIS_CONFIG_C,
                  NFMC_G              => NFMC_C )
    port map (
      fmc_to_cpld      => fmc_to_cpld,
      front_io_fmc     => front_io_fmc,
      --
      clk_to_fpga_p    => clk_to_fpga_p,
      clk_to_fpga_n    => clk_to_fpga_n,
      ext_trigger_p    => ext_trigger_p,
      ext_trigger_n    => ext_trigger_n,
      sync_from_fpga_p => sync_from_fpga_p,
      sync_from_fpga_n => sync_from_fpga_n,
      --
      adcInput         => adcInput,
      --
      pg_m2c           => pg_m2c,
      prsnt_m2c_l      => prsnt_m2c_l,
      --
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => axilWriteMasters(0),
      axilWriteSlave      => axilWriteSlaves (0),
      axilReadMaster      => axilReadMasters (0),
      axilReadSlave       => axilReadSlaves  (0),
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave,
      -- EVR Ports
      evrClk              => timingRecClk,
      evrRst              => timingRecClkRst,
      evrBus              => timingBus,
      timingFbClk         => '0',
      timingFbRst         => '0' );

end rtl;
