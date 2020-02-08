-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2020-02-07
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

entity AxiPcieDma is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      USE_IP_CORE_G    : boolean                := false;
      AXIL_BASE_ADDR_G : slv(31 downto 0)       := x"00000000";
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C;
      AXIS_CONFIG_G    : AxiStreamConfigArray);
   port (
      -- Clock and reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- AXI4 Interfaces
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      -- AXI4-Lite Interfaces
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Interrupts
      interrupt       : out slv(DMA_SIZE_G-1 downto 0);
      interruptAck    : in  sl;
      -- DMA Interfaces
      dmaClk          : in  slv(DMA_SIZE_G-1 downto 0);
      dmaRst          : in  slv(DMA_SIZE_G-1 downto 0);
      dmaObMasters    : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves     : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters    : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves     : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0));   
end AxiPcieDma;

architecture mapping of AxiPcieDma is

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,               -- 32-bit address interface
      DATA_BYTES_C => 32,               -- 32 bytes (256-bit interface)
      ID_BITS_C    => 4,                -- Up to 16 DMA channels
      LEN_BITS_C   => 8);               -- 8-bit awlen/arlen interface

   constant PCIE_AXIS_CONFIG_C : AxiStreamConfigType := AXIS_CONFIG_G(0);
     
   function DmaAxiLiteConfig return AxiLiteCrossbarMasterConfigArray is
      variable retConf : AxiLiteCrossbarMasterConfigArray((2*DMA_SIZE_G)-1 downto 0);
      variable addr    : slv(31 downto 0);
   begin
      addr := AXIL_BASE_ADDR_G;
      for i in (2*DMA_SIZE_G)-1 downto 0 loop
         addr(14 downto 10)      := toSlv(i, 5);
         retConf(i).baseAddr     := addr;
         retConf(i).addrBits     := 10;
         retConf(i).connectivity := x"FFFF";
      end loop;
      return retConf;
   end function;

   signal locReadMasters : AxiReadMasterArray(DMA_SIZE_G-1 downto 0);
   signal locReadSlaves  : AxiReadSlaveArray(DMA_SIZE_G-1 downto 0);
   signal axiReadMasters : AxiReadMasterArray(15 downto 0) := (others => AXI_READ_MASTER_FORCE_C);
   signal axiReadSlaves  : AxiReadSlaveArray(15 downto 0)  := (others => AXI_READ_SLAVE_FORCE_C);

   signal locWriteMasters : AxiWriteMasterArray(DMA_SIZE_G-1 downto 0);
   signal locWriteSlaves  : AxiWriteSlaveArray(DMA_SIZE_G-1 downto 0);
   signal locWriteCtrl    : AxiCtrlArray(DMA_SIZE_G-1 downto 0);
   signal axiWriteMasters : AxiWriteMasterArray(15 downto 0) := (others => AXI_WRITE_MASTER_FORCE_C);
   signal axiWriteSlaves  : AxiWriteSlaveArray(15 downto 0)  := (others => AXI_WRITE_SLAVE_FORCE_C);

   signal sAxisMasters : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal sAxisSlaves  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);

   signal mAxisMasters : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal mAxisSlaves  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal mAxisCtrl    : AxiStreamCtrlArray(DMA_SIZE_G-1 downto 0);

   signal axilReadMasters  : AxiLiteReadMasterArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray((2*DMA_SIZE_G)-1 downto 0);

   constant DEBUG_C : boolean := false;

   component ila_0
     port ( clk : in sl;
            probe0 : in slv(255 downto 0) );
   end component;

   signal idmaIbSlaves : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   
begin

   dmaIbSlaves <= idmaIbSlaves;
   
   GEN_DBUG : if DEBUG_C generate
     U_ILA0 : ila_0
       port map ( clk  => dmaClk(0),
                  probe0(0) => dmaIbMasters(0).tValid,
                  probe0(1) => dmaIbMasters(0).tLast,
                  probe0(65 downto 2) => dmaIbMasters(0).tData(63 downto 0),
                  probe0(66) => idmaIbSlaves(0).tReady,
                  probe0(67) => dmaRst(0),
                  probe0(255 downto 68) => (others=>'0') );
     U_ILA1 : ila_0
       port map ( clk  => axiClk,
                  probe0(0) => sAxisMasters(0).tValid,
                  probe0(1) => sAxisMasters(0).tLast,
                  probe0(65 downto 2) => sAxisMasters(0).tData(63 downto 0),
                  probe0(66) => sAxisSlaves(0).tReady,
                  probe0(67) => axiRst,
                  probe0(255 downto 68) => (others=>'0') );
   end generate;

   GEN_IP_CORE : if (USE_IP_CORE_G = true) generate
      U_AxiCrossbar : entity work.AxiPcieCrossbarIpCoreWrapper
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and reset
            axiClk           => axiClk,
            axiRst           => axiRst,
            -- Slaves
            sAxiWriteMasters => axiWriteMasters,
            sAxiWriteSlaves  => axiWriteSlaves,
            sAxiReadMasters  => axiReadMasters,
            sAxiReadSlaves   => axiReadSlaves,
            -- Master
            mAxiWriteMaster  => axiWriteMaster,
            mAxiWriteSlave   => axiWriteSlave,
            mAxiReadMaster   => axiReadMaster,
            mAxiReadSlave    => axiReadSlave);           
   end generate;

   GEN_RTL : if (USE_IP_CORE_G = false) generate
      --------------------
      -- AXI Read Path MUX
      --------------------
      U_AxiReadPathMux : entity surf.AxiReadPathMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => DMA_SIZE_G) 
         port map (
            -- Clock and reset
            axiClk          => axiClk,
            axiRst          => axiRst,
            -- Slaves
            sAxiReadMasters => axiReadMasters(DMA_SIZE_G-1 downto 0),
            sAxiReadSlaves  => axiReadSlaves(DMA_SIZE_G-1 downto 0),
            -- Master
            mAxiReadMaster  => axiReadMaster,
            mAxiReadSlave   => axiReadSlave);   

      -----------------------
      -- AXI Write Path DEMUX
      -----------------------
      U_AxiWritePathMux : entity surf.AxiWritePathMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => DMA_SIZE_G) 
         port map (
            -- Clock and reset
            axiClk           => axiClk,
            axiRst           => axiRst,
            -- Slaves
            sAxiWriteMasters => axiWriteMasters(DMA_SIZE_G-1 downto 0),
            sAxiWriteSlaves  => axiWriteSlaves(DMA_SIZE_G-1 downto 0),
            -- Master
            mAxiWriteMaster  => axiWriteMaster,
            mAxiWriteSlave   => axiWriteSlave);            
   end generate;

   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => (2*DMA_SIZE_G),
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         MASTERS_CONFIG_G   => DmaAxiLiteConfig) 
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);         

   ---------------
   -- DMA Channels
   ---------------
   U_DmaChanGen : for i in DMA_SIZE_G-1 downto 0 generate

      -----------
      -- DMA Core
      -----------
      U_AxiStreamDma : entity work.AxiStreamDmaDaq
         generic map (
            TPD_G             => TPD_G,
            -- AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,-- not implemented yet
            FREE_ADDR_WIDTH_G => 9,
            AXIL_COUNT_G      => 2,
            AXIL_BASE_ADDR_G  => AXIL_BASE_ADDR_G,
            AXI_READY_EN_G    => true,
            AXIS_READY_EN_G   => true,
            AXIS_CONFIG_G     => PCIE_AXIS_CONFIG_C,
            AXI_CONFIG_G      => AXI_CONFIG_C,
            AXI_BURST_G       => "01",    -- INCR 
            AXI_CACHE_G       => "0000")  -- Device Non-bufferable 
         port map (
            axiClk          => axiClk,
            axiRst          => axiRst,
            axilReadMaster  => axilReadMasters((i*2)+1 downto i*2),
            axilReadSlave   => axilReadSlaves((i*2)+1 downto i*2),
            axilWriteMaster => axilWriteMasters((i*2)+1 downto i*2),
            axilWriteSlave  => axilWriteSlaves((i*2)+1 downto i*2),
            interrupt       => interrupt(i),
            interruptAck    => interruptAck,
            sAxisMaster     => sAxisMasters(i),
            sAxisSlave      => sAxisSlaves(i),
            mAxisMaster     => mAxisMasters(i),
            mAxisSlave      => mAxisSlaves(i),
            mAxisCtrl       => mAxisCtrl(i),
            axiReadMaster   => locReadMasters(i),
            axiReadSlave    => locReadSlaves(i),
            axiWriteMaster  => locWriteMasters(i),
            axiWriteSlave   => locWriteSlaves(i),
            axiWriteCtrl    => locWriteCtrl(i));

      --------------------------
      -- Inbound AXI Stream FIFO
      --------------------------
      U_IbFifo : entity surf.AxiStreamFifo
         generic map (
--            DEBUG_G             => false,
            TPD_G               => TPD_G,
--            PIPE_STAGES_G       => 1,
--  Seeing incorrect response to mAxisSlave.tReady            
            PIPE_STAGES_G       => 0,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 4,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 12,
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G(i),
            MASTER_AXI_CONFIG_G => PCIE_AXIS_CONFIG_C) 
         port map (
            sAxisClk        => dmaClk(i),
            sAxisRst        => dmaRst(i),
            sAxisMaster     => dmaIbMasters(i),
            sAxisSlave      => idmaIbSlaves(i),
            sAxisCtrl       => open,
            fifoPauseThresh => (others => '1'),
            mAxisClk        => axiClk,
            mAxisRst        => axiRst,
            mAxisMaster     => sAxisMasters(i),
            mAxisSlave      => sAxisSlaves(i));

      ---------------------------
      -- Outbound AXI Stream FIFO
      ---------------------------
      U_ObFifo : entity surf.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => 1,
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 4,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 12,
            SLAVE_AXI_CONFIG_G  => PCIE_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_CONFIG_G(i)) 
         port map (
            sAxisClk        => axiClk,
            sAxisRst        => axiRst,
            sAxisMaster     => mAxisMasters(i),
            sAxisSlave      => mAxisSlaves(i),
            sAxisCtrl       => mAxisCtrl(i),
            fifoPauseThresh => (others => '1'),
            mAxisClk        => dmaClk(i),
            mAxisRst        => dmaRst(i),
            mAxisMaster     => dmaObMasters(i),
            mAxisSlave      => dmaObSlaves(i));

      ---------------------
      -- Read Path AXI FIFO
      ---------------------
      U_AxiReadPathFifo : entity surf.AxiReadPathFifo
         generic map (
            TPD_G                  => TPD_G,
            GEN_SYNC_FIFO_G        => true,
            ADDR_LSB_G             => 3,
            ID_FIXED_EN_G          => true,
            SIZE_FIXED_EN_G        => true,
            BURST_FIXED_EN_G       => true,
            LEN_FIXED_EN_G         => false,
            LOCK_FIXED_EN_G        => true,
            PROT_FIXED_EN_G        => true,
            CACHE_FIXED_EN_G       => true,
            ADDR_CASCADE_SIZE_G    => 1,
            ADDR_FIFO_ADDR_WIDTH_G => 4,
            DATA_CASCADE_SIZE_G    => 1,
            DATA_FIFO_ADDR_WIDTH_G => 4,
            AXI_CONFIG_G           => AXI_CONFIG_C) 
         port map (
            sAxiClk        => axiClk,
            sAxiRst        => axiRst,
            sAxiReadMaster => locReadMasters(i),
            sAxiReadSlave  => locReadSlaves(i),
            mAxiClk        => axiClk,
            mAxiRst        => axiRst,
            mAxiReadMaster => axiReadMasters(i),
            mAxiReadSlave  => axiReadSlaves(i));

      ----------------------
      -- Write Path AXI FIFO
      ----------------------
      U_AxiWritePathFifo : entity surf.AxiWritePathFifo
         generic map (
            TPD_G                    => TPD_G,
            GEN_SYNC_FIFO_G          => true,
            ADDR_LSB_G               => 3,
            ID_FIXED_EN_G            => true,
            SIZE_FIXED_EN_G          => true,
            BURST_FIXED_EN_G         => true,
            LEN_FIXED_EN_G           => false,
            LOCK_FIXED_EN_G          => true,
            PROT_FIXED_EN_G          => true,
            CACHE_FIXED_EN_G         => true,
            ADDR_CASCADE_SIZE_G      => 1,
            ADDR_FIFO_ADDR_WIDTH_G   => 9,
            DATA_CASCADE_SIZE_G      => 1,
            DATA_FIFO_ADDR_WIDTH_G   => 4,
            DATA_FIFO_PAUSE_THRESH_G => 12,
            RESP_CASCADE_SIZE_G      => 1,
            RESP_FIFO_ADDR_WIDTH_G   => 4,
            AXI_CONFIG_G             => AXI_CONFIG_C) 
         port map (
            sAxiClk         => axiClk,
            sAxiRst         => axiRst,
            sAxiWriteMaster => locWriteMasters(i),
            sAxiWriteSlave  => locWriteSlaves(i),
            sAxiCtrl        => locWriteCtrl(i),
            mAxiClk         => axiClk,
            mAxiRst         => axiRst,
            mAxiWriteMaster => axiWriteMasters(i),
            mAxiWriteSlave  => axiWriteSlaves(i));

   end generate;

end mapping;
