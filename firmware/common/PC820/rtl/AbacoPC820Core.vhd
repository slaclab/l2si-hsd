-------------------------------------------------------------------------------
-- File       : AbacoPC820Core.vhd
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;
use surf.I2cPkg.all;

library axi_pcie_core;
use axi_pcie_core.AxiPciePkg.all;
use axi_pcie_core.AxiPcieRegPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AbacoPC820Core is
   generic (
      TPD_G                : time                        := 1 ns;
      ROGUE_SIM_EN_G       : boolean                     := false;
      ROGUE_SIM_PORT_NUM_G : natural range 1024 to 49151 := 8000;
      ROGUE_SIM_CH_COUNT_G : natural range 1 to 256      := 256;
      BUILD_INFO_G         : BuildInfoType;
      DEVICE_MAP_G         : I2cAxiLiteDevArray;
      DMA_AXIS_CONFIG_G    : AxiStreamConfigType;
      DRIVER_TYPE_ID_G     : slv(31 downto 0)            := x"00000000";
      AXI_COMMON_CLK_G     : boolean                      := false;
      DMA_BURST_BYTES_G    : positive range 256 to 4096  := 256;
      DMA_SIZE_G           : positive range 1 to 8       := 1;
      TIMING_CORE_G        : string := "NONE" ); -- LCLSI, LCLSII, or NONE 
   port (
      ------------------------
      --  Top Level Interfaces
      ------------------------
      sysClk          : out sl;
      sysRst          : out sl;
      -- DMA Interfaces  (dmaClk domain)
      dmaClk          : in  sl;
      dmaRst          : in  sl;
--      dmaBuffGrpPause : out slv(7 downto 0);
      dmaObMasters    : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves     : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters    : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves     : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Application AXI-Lite Interfaces [0x00100000:0x00FFFFFF] (appClk domain)
      appClk          : in  sl;
      appRst          : in  sl;
      appReadMaster   : out AxiLiteReadMasterType;
      appReadSlave    : in  AxiLiteReadSlaveType;
      appWriteMaster  : out AxiLiteWriteMasterType;
      appWriteSlave   : in  AxiLiteWriteSlaveType;
      -------------------
      --  Top Level Ports
      -------------------
      -- System Ports
--      emcClk          : in  sl;
      -- Boot Memory Ports
      flashAddr      : out   slv(25 downto 0);
      flashData      : inout slv(15 downto 0);
      flashOe_n      : out   sl;
      flashWe_n      : out   sl;
      -- I2C
      scl            : inout sl;
      sda            : inout sl;
      -- Timing
      timingRefClk   : in  sl := '0';
      timingRxP      : in  sl := '0';
      timingRxN      : in  sl := '0';
      timingTxP      : out sl;
      timingTxN      : out sl;
      timingRecClk   : out sl;
      timingRecClkRst: out sl;
      timingBus      : out TimingBusType;
      timingFb       : in  TimingPhyType := TIMING_PHY_INIT_C;
      timingFbClk    : out sl;
      timingFbRst    : out sl;
      -- PCIe Ports
      pciRstL         : in  sl;
      pciRefClkP      : in  sl;
      pciRefClkN      : in  sl;
      pciRxP          : in  slv(7 downto 0);
      pciRxN          : in  slv(7 downto 0);
      pciTxP          : out slv(7 downto 0);
      pciTxN          : out slv(7 downto 0));
end AbacoPC820Core;

architecture mapping of AbacoPC820Core is

   signal dmaReadMaster  : AxiReadMasterType;
   signal dmaReadSlave   : AxiReadSlaveType;
   signal dmaWriteMaster : AxiWriteMasterType;
   signal dmaWriteSlave  : AxiWriteSlaveType;

   signal regReadMaster  : AxiReadMasterType;
   signal regReadSlave   : AxiReadSlaveType;
   signal regWriteMaster : AxiWriteMasterType;
   signal regWriteSlave  : AxiWriteSlaveType;

   signal dmaCtrlReadMasters  : AxiLiteReadMasterArray(2 downto 0);
   signal dmaCtrlReadSlaves   : AxiLiteReadSlaveArray(2 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_OK_C);
   signal dmaCtrlWriteMasters : AxiLiteWriteMasterArray(2 downto 0);
   signal dmaCtrlWriteSlaves  : AxiLiteWriteSlaveArray(2 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);

   signal phyReadMaster  : AxiLiteReadMasterType;
   signal phyReadSlave   : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
   signal phyWriteMaster : AxiLiteWriteMasterType;
   signal phyWriteSlave  : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;

   signal flsReadMaster  : AxiLiteReadMasterType;
   signal flsReadSlave   : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
   signal flsWriteMaster : AxiLiteWriteMasterType;
   signal flsWriteSlave  : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;

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

   signal sysClock    : sl;
   signal sysReset    : sl;
   signal systemReset : sl;
   signal cardReset   : sl;
   signal userClock   : sl;
   signal dmaIrq      : sl;

   signal flash_clk      : sl;
   signal flash_rst      : sl;
   signal flash_data_in  : slv(15 downto 0);
   signal flash_data_out : slv(15 downto 0);
   signal flash_data_tri : sl;
   signal flash_data_dts : slv(3 downto 0);
   signal flash_nce : sl;

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

   signal dmaObMastersAxi    : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaObSlavesAxi     : AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0);
   signal dmaIbMastersAxi    : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaIbSlavesAxi     : AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0);

   constant DEBUG_C : boolean := true;

   component ila_0
     port ( clk     : in sl;
            probe0  : in slv(255 downto 0) );
   end component;
   
begin

  -- GEN_DEBUG : if DEBUG_C generate
  --   U_ILA : ila_0
  --     port map ( clk                    => dmaClk,
  --                probe0(0)              => dmaIbMasters(0).tValid,
  --                probe0(1)              => dmaIbMasters(0).tLast,
  --                probe0(33 downto 2)    => dmaIbMasters(0).tData(31 downto 0),
  --                probe0(34)             => dmaIbMasters(1).tValid,
  --                probe0(35)             => dmaIbMasters(1).tLast,
  --                probe0(67 downto 36)   => dmaIbMasters(1).tData(31 downto 0),
  --                probe0(255 downto 68)  => (others=>'0') );
  -- end generate;

   sysClk <= sysClock;
   
   U_Rst : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => sysClock,
         rstIn  => systemReset,
         rstOut => sysRst);

   systemReset <= sysReset or cardReset;

   ---------------
   -- AXI PCIe PHY
   ---------------
   REAL_PCIE : if (not ROGUE_SIM_EN_G) generate
      U_AxiPciePhy : entity work.AbacoPC820PciePhyWrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- AXI4 Interfaces
            axiClk         => sysClock,
            axiRst         => sysReset,
            dmaReadMaster  => dmaReadMaster,
            dmaReadSlave   => dmaReadSlave,
            dmaWriteMaster => dmaWriteMaster,
            dmaWriteSlave  => dmaWriteSlave,
            regReadMaster  => regReadMaster,
            regReadSlave   => regReadSlave,
            regWriteMaster => regWriteMaster,
            regWriteSlave  => regWriteSlave,
            phyReadMaster  => phyReadMaster,
            phyReadSlave   => phyReadSlave,
            phyWriteMaster => phyWriteMaster,
            phyWriteSlave  => phyWriteSlave,
            -- Interrupt Interface
            dmaIrq         => dmaIrq,
            -- PCIe Ports
            pciRstL        => pciRstL,
            pciRefClkP     => pciRefClkP,
            pciRefClkN     => pciRefClkN,
            pciRxP         => pciRxP,
            pciRxN         => pciRxN,
            pciTxP         => pciTxP,
            pciTxN         => pciTxN);
   end generate;
   SIM_PCIE : if (ROGUE_SIM_EN_G) generate
      U_sysClock : entity surf.ClkRst
         generic map (
            CLK_PERIOD_G      => 8 ns,  -- 125 MHz
            RST_START_DELAY_G => 0 ns,
            RST_HOLD_TIME_G   => 1000 ns)
         port map (
            clkP => sysClock,
            rst  => sysReset);
   end generate;

   ---------------
   -- AXI PCIe REG
   ---------------
   U_REG : entity work.AxiPcieReg
      generic map (
         TPD_G                => TPD_G,
         BUILD_INFO_G         => BUILD_INFO_G,
         XIL_DEVICE_G         => "ULTRASCALE",
         BOOT_PROM_G          => "NONE",
         DRIVER_TYPE_ID_G     => DRIVER_TYPE_ID_G,
         AXI_COMMON_CLK_G     => AXI_COMMON_CLK_G,
         DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G,
         DMA_SIZE_G           => DMA_SIZE_G,
         EN_XVC_G             => false )
      port map (
         -- AXI4 Interfaces
         axiClk              => sysClock,
         axiRst              => sysReset,
         regReadMaster       => regReadMaster,
         regReadSlave        => regReadSlave,
         regWriteMaster      => regWriteMaster,
         regWriteSlave       => regWriteSlave,
         -- DMA AXI-Lite Interfaces
         dmaCtrlReadMasters  => dmaCtrlReadMasters,
         dmaCtrlReadSlaves   => dmaCtrlReadSlaves,
         dmaCtrlWriteMasters => dmaCtrlWriteMasters,
         dmaCtrlWriteSlaves  => dmaCtrlWriteSlaves,
         -- PHY AXI-Lite Interfaces
         phyReadMaster       => phyReadMaster,
         phyReadSlave        => phyReadSlave,
         phyWriteMaster      => phyWriteMaster,
         phyWriteSlave       => phyWriteSlave,
         -- FLASH AXI-Lite Interfaces
         flsReadMaster       => flsReadMaster,
         flsReadSlave        => flsReadSlave,
         flsWriteMaster      => flsWriteMaster,
         flsWriteSlave       => flsWriteSlave,
         -- I2C AXI-Lite Interfaces
         i2cReadMaster       => i2cReadMaster,
         i2cReadSlave        => i2cReadSlave,
         i2cWriteMaster      => i2cWriteMaster,
         i2cWriteSlave       => i2cWriteSlave,
         -- GTH AXI-Lite Interfaces
         gthReadMaster       => gthReadMaster,
         gthReadSlave        => gthReadSlave,
         gthWriteMaster      => gthWriteMaster,
         gthWriteSlave       => gthWriteSlave,
         -- Timing AXI-Lite Interfaces
         timReadMaster       => timReadMaster,
         timReadSlave        => timReadSlave,
         timWriteMaster      => timWriteMaster,
         timWriteSlave       => timWriteSlave,
         -- (Optional) Application AXI-Lite Interfaces
         appClk              => appClk,
         appRst              => appRst,
         appReadMaster       => appReadMaster,
         appReadSlave        => appReadSlave,
         appWriteMaster      => appWriteMaster,
         appWriteSlave       => appWriteSlave,
         -- Application Force reset
         cardResetOut        => cardReset,
         cardResetIn         => systemReset );

   flash_data_dts <= (others=>flash_data_tri);
   
   U_STARTUPE3 : STARTUPE3
      generic map (
         PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
         SIM_CCLK_FREQ => 0.0)  -- Set the Configuration Clock Frequency(ns) for simulation
      port map (
         CFGCLK    => open,  -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         DI        => flash_data_in(3 downto 0),  -- 4-bit output: Allow receiving on the D[3:0] input pins
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
         DO        => flash_data_out(3 downto 0),  -- 4-bit input: Allows control of the D[3:0] pin outputs
         DTS       => flash_data_dts,  -- 4-bit input: Allows tristate of the D[3:0] pins
         FCSBO     => flash_nce,  -- 1-bit input: Contols the FCS_B pin for flash access
         FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '1',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => flash_clk,         -- 1-bit input: User CCLK input
         USRCCLKTS => '1',  -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '0',  -- 1-bit input: User DONE pin output control
         USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output

   U_Clk : entity surf.ClockManagerUltraScale
     generic map ( INPUT_BUFG_G      => false,
                   NUM_CLOCKS_G       => 1,
                   CLKIN_PERIOD_G     => 8.0,
                   CLKFBOUT_MULT_F_G  => 8.0,
                   CLKOUT0_DIVIDE_F_G => 10.0 )
     port map ( clkIn => sysClock,
                rstIn => sysReset,
                clkOut(0) => flash_clk,
                rstOut(0) => flash_rst );

   GEN_FLASH : for i in 4 to 15 generate
     U_IOB : IOBUF
       port map ( I  => flash_data_out(i),
                  O  => flash_data_in (i),
                  IO => flashData     (i),
                  T  => flash_data_tri );
   end generate GEN_FLASH;

   U_FLASH : entity work.parallel_flash_if
     generic map ( START_ADDR => x"0000000",
                   STOP_ADDR  => x"0000020" )
     port map ( flash_clk       => flash_clk,
                axilClk         => sysClock,
                axilRst         => sysReset,
                axilWriteMaster => flsWriteMaster,
                axilWriteSlave  => flsWriteSlave,
                axilReadMaster  => flsReadMaster,
                axilReadSlave   => flsReadSlave,
                flash_address   => flashAddr,
                flash_data_o    => flash_data_out,
                flash_data_i    => flash_data_in ,
                flash_data_tri  => flash_data_tri,
                flash_noe       => flashOe_n,
                flash_nwe       => flashWe_n,
                flash_nce       => flash_nce );

   ---------------
   -- AXI PCIe DMA
   ---------------
   GEN_DMA : for i in DMA_SIZE_G-1 downto 0 generate
     U_IbFifo : entity surf.AxiStreamFifoV2
       generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G)
       port map (
         -- Slave Port
         sAxisClk    => dmaClk,
         sAxisRst    => dmaRst,
         sAxisMaster => dmaIbMasters(i),
         sAxisSlave  => dmaIbSlaves(i),
         -- Master Port
         mAxisClk    => sysClock,
         mAxisRst    => sysReset,
         mAxisMaster => dmaIbMastersAxi(i),
         mAxisSlave  => dmaIbSlavesAxi (i));
     U_ObFifo : entity surf.AxiStreamFifoV2
       generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G)
       port map (
         -- Slave Port
         sAxisClk    => sysClock,
         sAxisRst    => sysReset,
         sAxisMaster => dmaObMastersAxi(i),
         sAxisSlave  => dmaObSlavesAxi (i),
         -- Master Port
         mAxisClk    => dmaClk,
         mAxisRst    => dmaRst,
         mAxisMaster => dmaObMasters(i),
         mAxisSlave  => dmaObSlaves (i));
   end generate GEN_DMA;
     
   U_AxiPcieDma : entity axi_pcie_core.AxiPcieDma
      generic map (
         TPD_G                => TPD_G,
         ROGUE_SIM_EN_G       => ROGUE_SIM_EN_G,
         ROGUE_SIM_PORT_NUM_G => ROGUE_SIM_PORT_NUM_G,
         ROGUE_SIM_CH_COUNT_G => ROGUE_SIM_CH_COUNT_G,
         DMA_SIZE_G           => DMA_SIZE_G,
         DMA_BURST_BYTES_G    => DMA_BURST_BYTES_G,
         DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G)
      port map (
         axiClk           => sysClock,
         axiRst           => sysReset,
         -- AXI4 Interfaces (
         axiReadMaster    => dmaReadMaster,
         axiReadSlave     => dmaReadSlave,
         axiWriteMaster   => dmaWriteMaster,
         axiWriteSlave    => dmaWriteSlave,
         -- AXI4-Lite Interfaces
         axilReadMasters  => dmaCtrlReadMasters,
         axilReadSlaves   => dmaCtrlReadSlaves,
         axilWriteMasters => dmaCtrlWriteMasters,
         axilWriteSlaves  => dmaCtrlWriteSlaves,
         -- DMA Interfaces
         dmaIrq           => dmaIrq,
--         dmaBuffGrpPause  => dmaBuffGrpPause,
         dmaObMasters     => dmaObMastersAxi,
         dmaObSlaves      => dmaObSlavesAxi,
         dmaIbMasters     => dmaIbMastersAxi,
         dmaIbSlaves      => dmaIbSlavesAxi);

   intReadMasters (2) <= i2cReadMaster;
   intWriteMasters(2) <= i2cWriteMaster;
   i2cReadSlave       <= intReadSlaves (2);
   i2cWriteSlave      <= intWriteSlaves(2);
     
   U_I2C_Xbar : entity surf.AxiLiteCrossbar
     generic map ( NUM_SLAVE_SLOTS_G  => 2,
                   NUM_MASTER_SLOTS_G => 2,
                   MASTERS_CONFIG_G   => genAxiLiteConfig(2, I2C_ADDR_C, 16, 15) )
     port map ( axiClk              => sysClock,
                axiClkRst           => sysReset,
                sAxiReadMasters     => intReadMasters (3 downto 2),
                sAxiReadSlaves      => intReadSlaves  (3 downto 2),
                sAxiWriteMasters    => intWriteMasters(3 downto 2),
                sAxiWriteSlaves     => intWriteSlaves (3 downto 2),
                mAxiReadMasters     => intReadMasters (1 downto 0),
                mAxiReadSlaves      => intReadSlaves  (1 downto 0),
                mAxiWriteMasters    => intWriteMasters(1 downto 0),
                mAxiWriteSlaves     => intWriteSlaves (1 downto 0) );

   U_I2CProxy : entity surf.AxiLiteMasterProxy
     port map ( axiClk          => sysClock,
                axiRst          => sysReset,
                sAxiReadMaster  => intReadMasters (1),
                sAxiReadSlave   => intReadSlaves  (1),
                sAxiWriteMaster => intWriteMasters(1),
                sAxiWriteSlave  => intWriteSlaves (1),
                mAxiReadMaster  => intReadMasters (3),
                mAxiReadSlave   => intReadSlaves  (3),
                mAxiWriteMaster => intWriteMasters(3),
                mAxiWriteSlave  => intWriteSlaves (3) );
     
   U_I2C : entity surf.AxiI2cRegMaster
     generic map ( DEVICE_MAP_G   => DEVICE_MAP_G,
                   AXI_CLK_FREQ_G => 125.0E+6 )
     port map ( scl            => scl,
                sda            => sda,
                axiReadMaster  => intReadMasters (0),
                axiReadSlave   => intReadSlaves  (0),
                axiWriteMaster => intWriteMasters(0),
                axiWriteSlave  => intWriteSlaves (0),
                axiClk         => sysClock,
                axiRst         => sysReset );

   GEN_TIMING : if TIMING_CORE_G/="NONE" generate

     timingClkRst   <= not(rxStatus.resetDone);

     timingRecClk   <= timingClk;
     timingRecClkRst<= timingClkRst;

     txUsrRst       <= not(txStatus.resetDone);

     rxUsrClk       <= timingClk;
     rxUsrClkActive <= '1';
  
     U_TimingGth : entity lcls_timing_core.TimingGtCoreWrapper
       generic map (
         EXTREF_G          => true,  -- because Si5338 can't generate 371MHz
         AXIL_BASE_ADDR_G  => GTH_ADDR_C,
         ADDR_BITS_G       => 11,
         GTH_DRP_OFFSET_G  => x"00000800" )
       port map (
         axilClk         => sysClock,
         axilRst         => sysReset,
         axilReadMaster  => gthReadMaster,
         axilReadSlave   => gthReadSlave,
         axilWriteMaster => gthWriteMaster,
         axilWriteSlave  => gthWriteSlave,
         stableClk       => sysClock,
         stableRst       => sysReset,
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
         CLKSEL_MODE_G     => TIMING_CORE_G,
--         PROG_DELAY_G      => true,
         AXIL_BASE_ADDR_G  => TIM_ADDR_C,
--         AXIL_RINGB        => true,
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
         axilClk         => sysClock,
         axilRst         => sysReset,
         axilReadMaster  => timReadMaster,
         axilReadSlave   => timReadSlave,
         axilWriteMaster => timWriteMaster,
         axilWriteSlave  => timWriteSlave);

   timingBus   <= intTimingBus;
   timingFbClk <= txUsrClk;
   timingFbRst <= txUsrRst;

   end generate;
   
end mapping;
