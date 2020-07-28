-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2020-03-05
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use work.AxiPcieRegPkg.all;

library l2si_core; 

entity AxiPcieReg is
   generic (
      TPD_G            : time                   := 1 ns;
      DRIVER_TYPE_ID_G : slv(31 downto 0)       := x"00000000";
      AXI_APP_BUS_EN_G : boolean                := false;
      AXI_CLK_FREQ_G   : real                   := 125.0E+6;   -- units of Hz
--      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C;
      XIL_DEVICE_G     : string                 := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      EN_XVC_G         : boolean := false;
      BUILD_INFO_G     : BuildInfoType );
   port (
      -- AXI4 Interfaces
      axiClk             : in  sl;
      axiRst             : in  sl;
      regReadMaster      : in  AxiReadMasterType;
      regReadSlave       : out AxiReadSlaveType;
      regWriteMaster     : in  AxiWriteMasterType;
      regWriteSlave      : out AxiWriteSlaveType;
      -- AXI-Lite Interfaces
      axilClk            : in  sl;
      axilRst            : in  sl;
      -- FLASH AXI-Lite Interfaces [0x00008000:0x0000FFFF]
      flsReadMaster      : out AxiLiteReadMasterType;
      flsReadSlave       : in  AxiLiteReadSlaveType;
      flsWriteMaster     : out AxiLiteWriteMasterType;
      flsWriteSlave      : in  AxiLiteWriteSlaveType;
      -- I2C AXI-Lite Interfaces [0x00010000:0x0001FFFF]
      i2cReadMaster      : out AxiLiteReadMasterType;
      i2cReadSlave       : in  AxiLiteReadSlaveType;
      i2cWriteMaster     : out AxiLiteWriteMasterType;
      i2cWriteSlave      : in  AxiLiteWriteSlaveType;
      -- DMA AXI-Lite Interfaces [0x00020000:0x0002FFFF]
      dmaCtrlReadMaster  : out AxiLiteReadMasterType;
      dmaCtrlReadSlave   : in  AxiLiteReadSlaveType;
      dmaCtrlWriteMaster : out AxiLiteWriteMasterType;
      dmaCtrlWriteSlave  : in  AxiLiteWriteSlaveType;
      -- PHY AXI-Lite Interfaces [0x00030000:0x00030FFF]
      phyReadMaster      : out AxiLiteReadMasterType;
      phyReadSlave       : in  AxiLiteReadSlaveType;
      phyWriteMaster     : out AxiLiteWriteMasterType;
      phyWriteSlave      : in  AxiLiteWriteSlaveType;
      -- GTH AXI-Lite Interfaces [0x00031000:0x00031FFF]
      gthReadMaster      : out AxiLiteReadMasterType;
      gthReadSlave       : in  AxiLiteReadSlaveType;
      gthWriteMaster     : out AxiLiteWriteMasterType;
      gthWriteSlave      : in  AxiLiteWriteSlaveType;
      -- Timing AXI-Lite Interfaces [0x00040000:0x0004FFFF]
      timReadMaster      : out AxiLiteReadMasterType;
      timReadSlave       : in  AxiLiteReadSlaveType;
      timWriteMaster     : out AxiLiteWriteMasterType;
      timWriteSlave      : in  AxiLiteWriteSlaveType;
      -- (Optional) Application AXI-Lite Interfaces [0x00080000:0x000FFFFF]
      appReadMaster      : out AxiLiteReadMasterType;
      appReadSlave       : in  AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
      appWriteMaster     : out AxiLiteWriteMasterType;
      appWriteSlave      : in  AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
      -- AxiVersion AXI-Lite Interfaces
      vsnReadMaster      : in  AxiLiteReadMasterType;
      vsnReadSlave       : out AxiLiteReadSlaveType;
      vsnWriteMaster     : in  AxiLiteWriteMasterType;
      vsnWriteSlave      : out AxiLiteWriteSlaveType;
      -- Interrupts
      interrupt          : in  slv(DMA_SIZE_G-1 downto 0));
end AxiPcieReg;

architecture mapping of AxiPcieReg is

   constant HSD_PGP_DEVICE_ID_C : slv(31 downto 0) := x"FC000000";
   
   constant NUM_AXI_MASTERS_C : natural := 9;

   constant VERSION_INDEX_C : natural := 0;
   constant FLASH_INDEX_C   : natural := 1;
   constant I2C_INDEX_C     : natural := 2;
   constant DMA_INDEX_C     : natural := 3;
   constant PHY_INDEX_C     : natural := 4;
   constant GTH_INDEX_C     : natural := 5;
   constant XVC_INDEX_C     : natural := 6;
   constant TIM_INDEX_C     : natural := 7;
   constant APP_INDEX_C     : natural := 8;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_INDEX_C => (
         baseAddr     => VERSION_ADDR_C,
         addrBits     => 15,
         connectivity => x"FFFF"),
      FLASH_INDEX_C   => (
         baseAddr     => FLASH_ADDR_C,
         addrBits     => 15,
         connectivity => x"FFFF"),
      I2C_INDEX_C     => (
         baseAddr     => I2C_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      DMA_INDEX_C     => (
         baseAddr     => DMA_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      PHY_INDEX_C     => (
         baseAddr     => PHY_ADDR_C,
         addrBits     => 12,
         connectivity => x"FFFF"),
      GTH_INDEX_C     => (
         baseAddr     => GTH_ADDR_C,
         addrBits     => 12,
         connectivity => x"FFFF"),
      XVC_INDEX_C     => (
         baseAddr     => XVC_ADDR_C,
         addrBits     => 12,
         connectivity => x"FFFF"),
      TIM_INDEX_C     => (
         baseAddr     => TIM_ADDR_C,
         addrBits     => 18,
         connectivity => x"FFFF"),
      APP_INDEX_C     => (
         baseAddr     => APP_ADDR_C,
         addrBits     => 19,
         connectivity => x"FFFF"));          

   constant VSN_AXI_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(0 downto 0) := ( 0 => (AXI_CROSSBAR_MASTERS_CONFIG_C(VERSION_INDEX_C)) );

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal maskReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal maskWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal mclk, mrst      : sl;
   signal maxiReadMaster  : AxiLiteReadMasterType;
   signal maxiReadSlave   : AxiLiteReadSlaveType;
   signal maxiWriteMaster : AxiLiteWriteMasterType;
   signal maxiWriteSlave  : AxiLiteWriteSlaveType;

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal userValues   : Slv32Array(63 downto 0) := (others => x"00000000");
   signal flashAddress : slv(30 downto 0);

   signal ivsnReadMaster      : AxiLiteReadMasterType;
   signal ivsnReadSlave       : AxiLiteReadSlaveType;
   signal ivsnWriteMaster     : AxiLiteWriteMasterType;
   signal ivsnWriteSlave      : AxiLiteWriteSlaveType;
   
   constant DEBUG_C : boolean := false;

   component ila_0
     port ( clk    : in sl;
            probe0 : in slv(255 downto 0) );
   end component;
begin

   GEN_DEBUG : if DEBUG_C generate
     U_ILA : ila_0
       port map ( clk       => axiClk,
                  probe0(0) => axilReadMaster.arvalid,
                  probe0(1) => axilReadMaster.rready,
                  probe0(2) => axilReadSlave .arready,
                  probe0(3) => axilReadSlave .rvalid,
                  probe0(4) => axilWriteMaster.awvalid,
                  probe0(5) => axilWriteMaster.wvalid,
                  probe0(6) => axilWriteMaster.bready,
                  probe0(7) => axilWriteSlave.awready,
                  probe0(8) => axilWriteSlave.wready,
                  probe0(9) => axilWriteSlave.bvalid,
                  probe0(41 downto 10) => axilReadMaster.araddr,
                  probe0(73 downto 42) => axilWriteMaster.awaddr,
                  probe0(75 downto 74) => axilReadSlave.rresp,
                  probe0(77 downto 76) => axilWriteSlave.bresp,
                  probe0(255 downto 78) => (others=>'0') );
   end generate;
   
   ---------------------------------------------------------------------------------------------
   -- Driver Polls the userValues to determine the firmware's configurations and interrupt state
   ---------------------------------------------------------------------------------------------
   userValues(0)(DMA_SIZE_G-1 downto 0) <= interrupt;
   userValues(1)                        <= toSlv(DMA_SIZE_G, 32);
   userValues(2)                        <= x"00000001" when(AXI_APP_BUS_EN_G)         else x"00000000";
   userValues(3)                        <= DRIVER_TYPE_ID_G;
   userValues(62)                       <= x"00000001" when(XIL_DEVICE_G = "7SERIES") else x"00000000";
   userValues(63)                       <= toSlv(getTimeRatio(AXI_CLK_FREQ_G, 1.0), 32);

   -------------------------          
   -- AXI-to-AXI-Lite Bridge
   -------------------------          
   U_AxiToAxiLite : entity surf.AxiToAxiLite
      generic map (
         TPD_G => TPD_G)
      port map (
         axiClk          => axiClk,
         axiClkRst       => axiRst,
         axiReadMaster   => regReadMaster,
         axiReadSlave    => regReadSlave,
         axiWriteMaster  => regWriteMaster,
         axiWriteSlave   => regWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave); 

   ---------------------------------------
   -- Mask off upper address for 1 MB BAR0
   ---------------------------------------
   maskWriteMaster.awaddr  <= x"000" & axilWriteMaster.awaddr(19 downto 0);
   maskWriteMaster.awprot  <= axilWriteMaster.awprot;
   maskWriteMaster.awvalid <= axilWriteMaster.awvalid;
   maskWriteMaster.wdata   <= axilWriteMaster.wdata;
   maskWriteMaster.wstrb   <= axilWriteMaster.wstrb;
   maskWriteMaster.wvalid  <= axilWriteMaster.wvalid;
   maskWriteMaster.bready  <= axilWriteMaster.bready;
   maskReadMaster.araddr   <= x"000" & axilReadMaster.araddr(19 downto 0);
   maskReadMaster.arprot   <= axilReadMaster.arprot;
   maskReadMaster.arvalid  <= axilReadMaster.arvalid;
   maskReadMaster.rready   <= axilReadMaster.rready;

   mclk <= axiClk;
   mrst <= axiRst;
   maxiReadMaster  <= maskReadMaster;
   axilReadSlave   <= maxiReadSlave;
   maxiWriteMaster <= maskWriteMaster;
   axilWriteSlave  <= maxiWriteSlave;
       
   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
--         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => mclk,
         axiClkRst           => mrst,
         sAxiWriteMasters(0) => maxiWriteMaster,
         sAxiWriteSlaves(0)  => maxiWriteSlave,
         sAxiReadMasters(0)  => maxiReadMaster,
         sAxiReadSlaves(0)   => maxiReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);         

   U_VSNXBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => 1,
         MASTERS_CONFIG_G   => VSN_AXI_XBAR_CONFIG_C )
      port map (
         axiClk              => mclk,
         axiClkRst           => mrst,
         sAxiWriteMasters(1) => vsnWriteMaster,
         sAxiWriteMasters(0) => axilWriteMasters(VERSION_INDEX_C),
         sAxiWriteSlaves (1) => vsnWriteSlave,
         sAxiWriteSlaves (0) => axilWriteSlaves (VERSION_INDEX_C),
         sAxiReadMasters (1) => vsnReadMaster,
         sAxiReadMasters (0) => axilReadMasters (VERSION_INDEX_C),
         sAxiReadSlaves  (1) => vsnReadSlave,
         sAxiReadSlaves  (0) => axilReadSlaves  (VERSION_INDEX_C),
         mAxiWriteMasters(0) => ivsnWriteMaster,
         mAxiWriteSlaves (0) => ivsnWriteSlave,
         mAxiReadMasters (0) => ivsnReadMaster,
         mAxiReadSlaves  (0) => ivsnReadSlave );         
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------   
   U_Version : entity surf.AxiVersion
      generic map (
         TPD_G            => TPD_G,
--         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         EN_DEVICE_DNA_G  => true,
         XIL_DEVICE_G     => XIL_DEVICE_G,
         DEVICE_ID_G      => HSD_PGP_DEVICE_ID_C,
         BUILD_INFO_G     => BUILD_INFO_G )
      port map (
         -- AXI-Lite Interface
         axiClk         => mclk,
         axiRst         => mrst,
         axiReadMaster  => ivsnReadMaster,
         axiReadSlave   => ivsnReadSlave,
         axiWriteMaster => ivsnWriteMaster,
         axiWriteSlave  => ivsnWriteSlave,
         -- Optional: user values
         userValues     => userValues);

   --------------------------
   -- Xilinx Virtual Cable Module
   --------------------------
   GEN_XVC : if EN_XVC_G generate
     -- JtagBridgeWrapper disables the external JTAG ports!
--     U_XVC : entity l2si_core.JtagBridgeWrapper
     U_XVC : entity l2si_core.DebugBridgeWrapper
       port map (
         axilClk         => mclk,
         axilRst         => mrst,
         axilReadMaster  => axilReadMasters (XVC_INDEX_C),
         axilReadSlave   => axilReadSlaves  (XVC_INDEX_C),
         axilWriteMaster => axilWriteMasters(XVC_INDEX_C),
         axilWriteSlave  => axilWriteSlaves (XVC_INDEX_C) );
   end generate;
   GEN_NOXVC : if not EN_XVC_G generate
     axilReadSlaves (XVC_INDEX_C) <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
     axilWriteSlaves(XVC_INDEX_C) <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
   end generate;
   
   ---------------------------------
   -- Map the AXI-Lite to FLASH Engine
   ---------------------------------
   flsWriteMaster                 <= axilWriteMasters(FLASH_INDEX_C);
   axilWriteSlaves(FLASH_INDEX_C) <= flsWriteSlave;
   flsReadMaster                  <= axilReadMasters(FLASH_INDEX_C);
   axilReadSlaves(FLASH_INDEX_C)  <= flsReadSlave;

   ---------------------------------
   -- Map the AXI-Lite to I2C Engine
   ---------------------------------
   i2cWriteMaster               <= axilWriteMasters(I2C_INDEX_C);
   axilWriteSlaves(I2C_INDEX_C) <= i2cWriteSlave;
   i2cReadMaster                <= axilReadMasters(I2C_INDEX_C);
   axilReadSlaves(I2C_INDEX_C)  <= i2cReadSlave;

   ---------------------------------
   -- Map the AXI-Lite to DMA Engine
   ---------------------------------

   dmaCtrlWriteMaster           <= axilWriteMasters(DMA_INDEX_C);
   axilWriteSlaves(DMA_INDEX_C) <= dmaCtrlWriteSlave;
   dmaCtrlReadMaster            <= axilReadMasters(DMA_INDEX_C);
   axilReadSlaves(DMA_INDEX_C)  <= dmaCtrlReadSlave;

   -------------------------------
   -- Map the AXI-Lite to PCIe PHY
   -------------------------------
   phyWriteMaster               <= axilWriteMasters(PHY_INDEX_C);
   axilWriteSlaves(PHY_INDEX_C) <= phyWriteSlave;
   phyReadMaster                <= axilReadMasters(PHY_INDEX_C);
   axilReadSlaves(PHY_INDEX_C)  <= phyReadSlave;

   -------------------------------
   -- Map the AXI-Lite to Timing PHY
   -------------------------------
   gthWriteMaster               <= axilWriteMasters(GTH_INDEX_C);
   axilWriteSlaves(GTH_INDEX_C) <= gthWriteSlave;
   gthReadMaster                <= axilReadMasters(GTH_INDEX_C);
   axilReadSlaves(GTH_INDEX_C)  <= gthReadSlave;

   -------------------------------
   -- Map the AXI-Lite to Timing
   -------------------------------
   timWriteMaster               <= axilWriteMasters(TIM_INDEX_C);
   axilWriteSlaves(TIM_INDEX_C) <= timWriteSlave;
   timReadMaster                <= axilReadMasters(TIM_INDEX_C);
   axilReadSlaves(TIM_INDEX_C)  <= timReadSlave;

   -------------------------------
   -- Map the AXI-Lite to APP
   -------------------------------
   appWriteMaster               <= axilWriteMasters(APP_INDEX_C);
   axilWriteSlaves(APP_INDEX_C) <= appWriteSlave;
   appReadMaster                <= axilReadMasters(APP_INDEX_C);
   axilReadSlaves(APP_INDEX_C)  <= appReadSlave;

end mapping;
