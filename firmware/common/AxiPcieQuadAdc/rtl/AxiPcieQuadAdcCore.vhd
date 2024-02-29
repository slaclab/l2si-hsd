-------------------------------------------------------------------------------
-- Title      : QuadAdc Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieQuadAdcCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2024-02-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'AxiPcieCore'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'AxiPcieCore', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.I2cPkg.all;

use work.AxiPciePkg.all;
use work.AxiPcieRegPkg.all;
use work.FmcPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library unisim;
use unisim.vcomponents.all;

library axi_pcie_core;
library l2si_core; 

entity AxiPcieQuadAdcCore is
  generic (
    TPD_G            : time                   := 1 ns;
    DRIVER_TYPE_ID_G : slv(31 downto 0)       := x"00000000";
    AXI_APP_BUS_EN_G : boolean                := false;
    ENABLE_DMA_G     : boolean                := true;
    DMA_SIZE_G       : positive range 1 to 16 := 1;
    AXIS_CONFIG_G    : AxiStreamConfigType;
    LCLSII_G         : boolean                := true;  -- obsolete
    SIM_PERIOD_G     : integer                := 13;
    BUILD_INFO_G     : BuildInfoType );
  port (
    -- System Clock and Reset
    sysClk         : out   sl;        -- 250 MHz
    sysRst         : out   sl;
    -- DMA Interfaces
    dmaClk         : in    slv(DMA_SIZE_G-1 downto 0);
    dmaRst         : in    slv(DMA_SIZE_G-1 downto 0);
    dmaObMasters   : out   AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
    dmaObSlaves    : in    AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
    dmaIbMasters   : in    AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
    dmaIbSlaves    : out   AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
    -- (Optional) Application AXI-Lite Interfaces [0x00080000:0x000FFFFF]
    regClk         : out   sl;        -- 125 MHz
    regRst         : out   sl;
    appReadMaster  : out   AxiLiteReadMasterType;
    appReadSlave   : in    AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
    appWriteMaster : out   AxiLiteWriteMasterType;
    appWriteSlave  : in    AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
    -- Boot Memory Ports
    flashAddr      : out   slv(25 downto 0);
    flashData      : inout slv(15 downto 0);
    flashOe_n      : out   sl;
    flashWe_n      : out   sl;

    -- I2C
    scl            : inout sl;
    sda            : inout sl;
    
    -- Timing
    timingRefClk   : in    sl;
    timingRxP      : in    sl;
    timingRxN      : in    sl;
    timingTxP      : out   sl;
    timingTxN      : out   sl;
    timingRecClk   : out   sl;
    timingRecClkRst: out   sl;
    timingBus      : out   TimingBusType;
    timingFbClk    : out   sl;
    timingFbRst    : out   sl;
    timingFb       : in    TimingPhyType;
    
    -- PCIe Ports 
    pciRstL        : in    sl;
    pciRefClkP     : in    sl;
    pciRefClkN     : in    sl;
    pciRxP         : in    slv(7 downto 0);
    pciRxN         : in    slv(7 downto 0);
    pciTxP         : out   slv(7 downto 0);
    pciTxN         : out   slv(7 downto 0));        
end AxiPcieQuadAdcCore;

architecture mapping of AxiPcieQuadAdcCore is

  signal regReadMaster  : AxiLiteReadMasterType;
  signal regReadSlave   : AxiLiteReadSlaveType;
  signal regWriteMaster : AxiLiteWriteMasterType;
  signal regWriteSlave  : AxiLiteWriteSlaveType;

  constant I2C_INDEX_C : integer := 0;
  constant GTH_INDEX_C : integer := 1;
  constant TIM_INDEX_C : integer := 2;
  constant APP_INDEX_C : integer := 3;
  constant NAXI_C : integer := 4;

  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NAXI_C-1 downto 0) := (
      I2C_INDEX_C     => (
         baseAddr     => x"0010_0000",
         addrBits     => 16,
         connectivity => x"FFFF"),
      GTH_INDEX_C     => (
         baseAddr     => x"0011_0000",
         addrBits     => 16,
         connectivity => x"FFFF"),
      TIM_INDEX_C     => (
         baseAddr     => x"0014_0000",
         addrBits     => 18,
         connectivity => x"FFFF"),
      APP_INDEX_C     => (
         baseAddr     => x"0020_0000",
         addrBits     => 20,
         connectivity => x"FFFF"));
        
  signal axilReadMasters  : AxiLiteReadMasterArray (NAXI_C-1 downto 0);
  signal axilReadSlaves   : AxiLiteReadSlaveArray  (NAXI_C-1 downto 0);
  signal axilWriteMasters : AxiLiteWriteMasterArray(NAXI_C-1 downto 0);
  signal axilWriteSlaves  : AxiLiteWriteSlaveArray (NAXI_C-1 downto 0);
  
  signal i2cReadMaster  : AxiLiteReadMasterType;
  signal i2cReadSlave   : AxiLiteReadSlaveType;
  signal i2cWriteMaster : AxiLiteWriteMasterType;
  signal i2cWriteSlave  : AxiLiteWriteSlaveType;

  -- I2C axi-lite proxy
  signal intReadMasters  : AxiLiteReadMasterArray (3 downto 0);
  signal intReadSlaves   : AxiLiteReadSlaveArray  (3 downto 0);
  signal intWriteMasters : AxiLiteWriteMasterArray(3 downto 0);
  signal intWriteSlaves  : AxiLiteWriteSlaveArray (3 downto 0);

  signal gthReadMaster  : AxiLiteReadMasterType;
  signal gthReadSlave   : AxiLiteReadSlaveType;
  signal gthWriteMaster : AxiLiteWriteMasterType;
  signal gthWriteSlave  : AxiLiteWriteSlaveType;

  signal timReadMaster  : AxiLiteReadMasterType;
  signal timReadSlave   : AxiLiteReadSlaveType;
  signal timWriteMaster : AxiLiteWriteMasterType;
  signal timWriteSlave  : AxiLiteWriteSlaveType;

  signal timingClk      : sl;
  signal timingClkRst   : sl;
  signal intTimingBus   : TimingBusType;
  signal rxStatus       : TimingPhyStatusType;
  signal rxControl      : TimingPhyControlType;
  signal rxUsrClk       : sl;
  signal rxUsrClkActive : sl;
  signal rxData         : slv(15 downto 0);
  signal rxDataK        : slv(1 downto 0);
  signal rxDispErr      : slv(1 downto 0);
  signal rxDecErr       : slv(1 downto 0);
  signal txUsrClk       : sl;
  signal txUsrRst       : sl;
  signal txStatus       : TimingPhyStatusType := TIMING_PHY_STATUS_INIT_C;
  signal loopback       : slv(2 downto 0);

  signal interrupt    : slv(DMA_SIZE_G-1 downto 0);
  
  signal axiClk  : sl;
  signal axiRst  : sl;
  signal axiRst0 : sl;
  signal axilClk : sl;
  signal axilRst : sl;
  signal dmaIrq  : sl;
  signal dmaIrqAck : sl;
  
  signal flash_data_in  : slv(15 downto 0);
  signal flash_data_out : slv(15 downto 0);
  signal flash_data_tri : sl;
  signal flash_data_dts : slv(3 downto 0);
  signal flash_nce : sl;

  signal timingSimClk : sl;
  
begin

  sysClk <= axiClk;
  sysRst <= axiRst;
  regClk <= axilClk;
  regRst <= axilRst;
  dmaIrq <= uOr(interrupt);
  
  U_Core : entity axi_pcie_core.AbacoPc821Core
    generic map (
      TPD_G                => TPD_G,
      ROGUE_SIM_EN_G       => false,
      BUILD_INFO_G         => BUILD_INFO_G,
      DMA_AXIS_CONFIG_G    => AXIS_CONFIG_G,
      DRIVER_TYPE_ID_G     => DRIVER_TYPE_ID_G,
      DMA_SIZE_G           => DMA_SIZE_G )
    port map (
      ------------------------
      --  Top Level Interfaces
      ------------------------
      -- DMA Interfaces  (dmaClk domain)
      dmaClk          => axiClk,
      dmaRst          => axiRst,
      dmaBuffGrpPause => open,
      dmaObMasters    => dmaObMasters,
      dmaObSlaves     => dmaObSlaves,
      dmaIbMasters    => dmaIbMasters,
      dmaIbSlaves     => dmaIbSlaves,
      -- Application AXI-Lite Interfaces [0x00100000:0x00FFFFFF] (appClk domain)
      appClk          => axilClk,
      appRst          => axilRst,
      appReadMaster   => regReadMaster,
      appReadSlave    => regReadSlave,
      appWriteMaster  => regWriteMaster,
      appWriteSlave   => regWriteSlave,
      -------------------
      --  Top Level Ports
      -------------------
      -- Boot Memory Ports
      flashAddr       => flashAddr,
      flashData       => flashData(15 downto 4),
      flashOeL        => flashOe_n,
      flashWeL        => flashWe_n,
      -- PCIe Ports
      pciRstL         => pciRstL,
      pciRefClkP      => pciRefClkP,
      pciRefClkN      => pciRefClkN,
      pciRxP          => pciRxP,
      pciRxN          => pciRxN,
      pciTxP          => pciTxP,
      pciTxN          => pciTxN );

   U_Clk : entity surf.ClockManagerUltraScale
     generic map ( INPUT_BUFG_G      => false,
                   NUM_CLOCKS_G       => 1,
                   CLKIN_PERIOD_G     => 4.0,
                   CLKFBOUT_MULT_F_G  => 5.0,
                   CLKOUT0_DIVIDE_F_G => 10.0 )
     port map ( clkIn => axiClk,
                rstIn => axiRst,
                clkOut(0) => axilClk,
                rstOut(0) => axilRst );

  U_App_Xbar : entity surf.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G  => 1,
                  NUM_MASTER_SLOTS_G => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C )
    port map ( axiClk              => axilClk,
               axiClkRst           => axilRst,
               sAxiReadMasters (0) => regReadMaster,
               sAxiReadSlaves  (0) => regReadSlave,
               sAxiWriteMasters(0) => regWriteMaster,
               sAxiWriteSlaves (0) => regWriteSlave,
               mAxiReadMasters     => axilReadMasters,
               mAxiReadSlaves      => axilReadSlaves,
               mAxiWriteMasters    => axilWriteMasters,
               mAxiWriteSlaves     => axilWriteSlaves );
  
  timingClkRst   <= not(rxStatus.resetDone);

  timingRecClk   <= timingClk;
  timingRecClkRst<= timingClkRst;

  txUsrRst       <= not(txStatus.resetDone);

  rxUsrClk       <= timingClk;
  rxUsrClkActive <= '1';
  
  U_TimingGth : entity lcls_timing_core.TimingGtCoreWrapper
    generic map (
      EXTREF_G          => true,  -- because Si5338 can't generate 371MHz
      ADDR_BITS_G       => 14,
      AXIL_BASE_ADDR_G  => AXIL_XBAR_CONFIG_C(GTH_INDEX_C).baseAddr )
    port map (
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => axilReadMasters (GTH_INDEX_C),
      axilReadSlave   => axilReadSlaves  (GTH_INDEX_C),
      axilWriteMaster => axilWriteMasters(GTH_INDEX_C),
      axilWriteSlave  => axilWriteSlaves (GTH_INDEX_C),
      stableClk       => axilClk,
      stableRst       => axilRst,
      gtRefClk        => timingRefClk,
      gtRefClkDiv2    => '0',
      gtRxP           => timingRxP,
      gtRxN           => timingRxN,
      gtTxP           => timingTxP,
      gtTxN           => timingTxN,
      rxControl       => rxControl,
      rxStatus        => rxStatus,
      rxUsrClkActive  => rxUsrClkActive,
      rxCdrStable     => open,
      rxUsrClk        => rxUsrClk,
      rxData          => rxData,
      rxDataK         => rxDataK,
      rxDispErr       => rxDispErr,
      rxDecErr        => rxDecErr,
      rxOutClk        => timingClk,
      txControl       => rxControl,
      txStatus        => txStatus,
      txUsrClk        => txUsrClk,
      txUsrClkActive  => '1',
      txData          => timingFb.data,
      txDataK         => timingFb.dataK,
      txOutClk        => txUsrClk,
      loopback        => loopback);
  
  TimingCore_1 : entity lcls_timing_core.TimingCore
    generic map (
      TPD_G             => TPD_G,
      TPGEN_G           => false,
      ASYNC_G           => false,
      CLKSEL_MODE_G     => "LCLSII",
      AXIL_BASE_ADDR_G  => AXIL_XBAR_CONFIG_C(TIM_INDEX_C).baseAddr,
      USE_TPGMINI_G     => true )
    port map (
      gtTxUsrClk      => txUsrClk,
      gtTxUsrRst      => txUsrRst,
      gtRxRecClk      => timingClk,
      gtRxData        => rxData,
      gtRxDataK       => rxDataK,
      gtRxDispErr     => rxDispErr,
      gtRxDecErr      => rxDecErr,
      gtRxControl     => rxControl,
      gtRxStatus      => rxStatus,
      gtLoopback      => loopback,
      appTimingClk    => timingClk,
      appTimingRst    => timingClkRst,
      appTimingBus    => intTimingBus,
      timingClkSel    => open,
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => axilReadMasters (TIM_INDEX_C),
      axilReadSlave   => axilReadSlaves  (TIM_INDEX_C),
      axilWriteMaster => axilWriteMasters(TIM_INDEX_C),
      axilWriteSlave  => axilWriteSlaves (TIM_INDEX_C));

  timingBus   <= intTimingBus;
  timingFbClk <= txUsrClk;
  timingFbRst <= txUsrRst;
  
  intReadMasters (2) <= axilReadMasters (I2C_INDEX_C);
  intWriteMasters(2) <= axilWriteMasters(I2C_INDEX_C);
  axilReadSlaves (I2C_INDEX_C) <= intReadSlaves (2);
  axilWriteSlaves(I2C_INDEX_C) <= intWriteSlaves(2);
  
  U_I2C_Xbar : entity surf.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G  => 2,
                  NUM_MASTER_SLOTS_G => 2,
                  MASTERS_CONFIG_G   => genAxiLiteConfig(2, AXIL_XBAR_CONFIG_C(I2C_INDEX_C).baseAddr, 16, 15) )
    port map ( axiClk              => axiClk,
               axiClkRst           => axiRst,
               sAxiReadMasters     => intReadMasters (3 downto 2),
               sAxiReadSlaves      => intReadSlaves  (3 downto 2),
               sAxiWriteMasters    => intWriteMasters(3 downto 2),
               sAxiWriteSlaves     => intWriteSlaves (3 downto 2),
               mAxiReadMasters     => intReadMasters (1 downto 0),
               mAxiReadSlaves      => intReadSlaves  (1 downto 0),
               mAxiWriteMasters    => intWriteMasters(1 downto 0),
               mAxiWriteSlaves     => intWriteSlaves (1 downto 0) );

  U_I2CProxy : entity surf.AxiLiteMasterProxy
    port map ( axiClk          => axiClk,
               axiRst          => axiRst,
               sAxiReadMaster  => intReadMasters (1),
               sAxiReadSlave   => intReadSlaves  (1),
               sAxiWriteMaster => intWriteMasters(1),
               sAxiWriteSlave  => intWriteSlaves (1),
               mAxiReadMaster  => intReadMasters (3),
               mAxiReadSlave   => intReadSlaves  (3),
               mAxiWriteMaster => intWriteMasters(3),
               mAxiWriteSlave  => intWriteSlaves (3) );
  
  U_I2C : entity surf.AxiI2cRegMaster
    generic map ( DEVICE_MAP_G   => DEVICE_MAP_C,
                  AXI_CLK_FREQ_G => 250.0E+6 )
    port map ( scl            => scl,
               sda            => sda,
               axiReadMaster  => intReadMasters (0),
               axiReadSlave   => intReadSlaves  (0),
               axiWriteMaster => intWriteMasters(0),
               axiWriteSlave  => intWriteSlaves (0),
               axiClk         => axiClk,
               axiRst         => axiRst );

  U_AXIL_ASYNC : entity surf.AxiLiteAsync
    port map ( sAxiClk         => axiClk,
               sAxiClkRst      => axiRst,
               sAxiReadMaster  => axilReadMasters (APP_INDEX_C),
               sAxiReadSlave   => axilReadSlaves  (APP_INDEX_C),
               sAxiWriteMaster => axilWriteMasters(APP_INDEX_C),
               sAxiWriteSlave  => axilWriteSlaves (APP_INDEX_C),
               mAxiClk         => axilClk,
               mAxiClkRst      => axilRst,
               mAxiReadMaster  => appReadMaster,
               mAxiReadSlave   => appReadSlave,
               mAxiWriteMaster => appWriteMaster,
               mAxiWriteSlave  => appWriteSlave );

end mapping;

