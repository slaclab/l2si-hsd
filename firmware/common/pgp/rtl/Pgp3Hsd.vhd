------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp3Hsd.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2023-03-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
--   Application interface to JungFrau.  Uses 10GbE.  Trigger is external TTL
--   (L0 only?). Control register access is external 1GbE link.
--
--   Intercept out-bound messages as register transactions for 10GbE core.
--   Use simulation embedding: ADDR(31:1) & RNW & DATA(31:0).
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp3Pkg.all;
use surf.SsiPkg.all;

library l2si_core;

entity Pgp3Hsd is
   generic (
      TPD_G               : time                := 1 ns;
      ID_G                : slv(7 downto 0)     := (others=>'0');
      ENABLE_TAG_G        : boolean             := false ;
      DEBUG_G             : boolean             := false ;
      AXIL_BASE_ADDR_G    : slv(31 downto 0)    := (others=>'0');
      AXIS_CONFIG_G       : AxiStreamConfigType );
   port (
     coreClk         : in  sl;
     coreRst         : in  sl;
     pgpRxP          : in  sl;
     pgpRxN          : in  sl;
     pgpTxP          : out sl;
     pgpTxN          : out sl;
     fifoRst         : in  sl;
     -- Quad PLL Ports
     qplllock        : in  sl;
     qplloutclk      : in  sl;
     qplloutrefclk   : in  sl;
     qpllRst         : out sl;
     --
     axilClk         : in  sl;
     axilRst         : in  sl;
     axilReadMaster  : in  AxiLiteReadMasterType;
     axilReadSlave   : out AxiLiteReadSlaveType;
     axilWriteMaster : in  AxiLiteWriteMasterType;
     axilWriteSlave  : out AxiLiteWriteSlaveType;
     holdoffSof      : in  sl := '0';
     disableFull     : in  sl := '0';
     --
     ibRst           : in  sl;
     linkUp          : out sl;
     rxReset         : in  sl := '0';
     rxErr           : out sl;
     --
     obClk           : in  sl;
     txReset         : in  sl := '0';
     txId            : in  slv(31 downto 0);
     obMaster        : in  AxiStreamMasterType;
     obSlave         : out AxiStreamSlaveType;
     --
     ibClk           : in  sl := '0';
     ibMaster        : out AxiStreamMasterType;
     ibSlave         : in  AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C );

end Pgp3Hsd;

architecture top_level_app of Pgp3Hsd is

  constant NUM_VC_C : integer := 2;
  
  signal pgpObMaster : AxiStreamMasterType;
  signal pgpObSlave  : AxiStreamSlaveType;

  signal pgpTxIn        : Pgp3TxInType := PGP3_TX_IN_INIT_C;
  signal pgpTxOut       : Pgp3TxOutType;
  signal pgpRxIn        : Pgp3RxInType := PGP3_RX_IN_INIT_C;
  signal pgpRxOut       : Pgp3RxOutType;
  signal pgpTxMasters   : AxiStreamMasterArray(NUM_VC_C-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal pgpTxSlaves    : AxiStreamSlaveArray (NUM_VC_C-1 downto 0);
  signal pgpRxMasters   : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
  signal pgpRxCtrls     : AxiStreamCtrlArray  (NUM_VC_C-1 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

  signal pgpClk         : sl;
  signal pgpRst         : sl;

  signal iqpllRst       : sl;
  signal full           : sl;
  signal holdoffSofS    : sl;
  signal disableFullS   : sl;
  
  type RegType is record
    tLast  : sl;
    opCode : sl;
    count  : slv(23 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    tLast  => '1',
    opCode => '0',
    count  => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  U_RxFifo : entity surf.AxiStreamFifoV2
    generic map (
      SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
      MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C,
      FIFO_ADDR_WIDTH_G   => 9,
      PIPE_STAGES_G       => 2 )
    port map ( 
      -- Slave Port
      sAxisClk    => pgpClk,
      sAxisRst    => fifoRst,
      sAxisMaster => pgpRxMasters(0),
      sAxisCtrl   => pgpRxCtrls  (0),
      -- Master Port
      mAxisClk    => ibClk,
      mAxisRst    => fifoRst,
      mAxisMaster => ibMaster,
      mAxisSlave  => ibSlave );

  pgpTxIn.flowCntlDis <= '1';
  pgpTxIn.skpInterval <= X"0000FFF0";
  pgpTxIn.resetTx     <= txReset;
  pgpTxIn.opCodeNumber<= toSlv(6,3);
  pgpTxIn.opCodeEn    <= r.opCode;
  pgpRxIn.resetRx     <= rxReset;

  U_SyncId : entity surf.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk       => pgpClk,
               dataIn    => txId,
               dataOut   => pgpTxIn.opCodeData(47 downto 16) );
  
  U_TxFifo : entity surf.AxiStreamFifoV2
    generic map (
      SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
      MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C,
      FIFO_ADDR_WIDTH_G   => 9,
      PIPE_STAGES_G       => 2 )
    port map ( 
      -- Slave Port
      sAxisClk    => obClk,
      sAxisRst    => fifoRst,
      sAxisMaster => obMaster,
      sAxisSlave  => obSlave,
      -- Master Port
      mAxisClk    => pgpClk,
      mAxisRst    => fifoRst,
      mAxisMaster => pgpObMaster,
      mAxisSlave  => pgpObSlave );

  linkUp                   <= pgpRxOut.linkReady;
  rxErr                    <= pgpRxOut.frameRxErr;
  qpllRst                  <= iqpllRst;
  
  U_PgpFb : entity l2si_core.DtiPgp3Fb
    port map ( pgpClk       => pgpClk,
               pgpRst       => pgpRst,
               pgpRxOut     => pgpRxOut,
               rxLinkId     => open,
               rxAlmostFull => full );

  U_Pgp3 : entity surf.Pgp3GthUs
    generic map ( NUM_VC_G     => NUM_VC_C,
                  EN_DRP_G     => false,
                  EN_PGP_MON_G => true,
                  AXIL_BASE_ADDR_G => AXIL_BASE_ADDR_G )
    port map ( -- Stable Clock and Reset
               stableClk    => axilClk,
               stableRst    => axilRst,
               -- QPLL Interface
               qpllLock  (0)=> qplllock,
               qpllLock  (1)=> '0',
               qpllclk   (0)=> qplloutclk,
               qpllclk   (1)=> '0',
               qpllrefclk(0)=> qplloutrefclk,
               qpllrefclk(1)=> '0',
               qpllRst   (0)=> iqpllRst,
               qpllRst   (1)=> open,
               -- Gt Serial IO
               pgpGtTxP     => pgpTxP,
               pgpGtTxN     => pgpTxN,
               pgpGtRxP     => pgpRxP,
               pgpGtRxN     => pgpRxN,
               -- Clocking
               pgpClk       => pgpClk,
               pgpClkRst    => pgpRst,
               -- Non VC Tx Signals
               pgpTxIn      => pgpTxIn,
               pgpTxOut     => pgpTxOut,
               -- Non VC Rx Signals
               pgpRxIn      => pgpRxIn,
               pgpRxOut     => pgpRxOut,
               -- Frame TX Interface
               pgpTxMasters => pgpTxMasters,
               pgpTxSlaves  => pgpTxSlaves,
               -- Frame RX Interface
               pgpRxMasters => pgpRxMasters,
               pgpRxCtrl    => pgpRxCtrls,
               -- AXI-Lite Register Interface
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMaster,
               axilReadSlave   => axilReadSlave,
               axilWriteMaster => axilWriteMaster,
               axilWriteSlave  => axilWriteSlave );

  U_Holdoff : entity surf.Synchronizer
    port map ( clk     => pgpClk,
               dataIn  => holdoffSof,
               dataOut => holdoffSofS );

  U_DisableFull : entity surf.Synchronizer
    port map ( clk     => pgpClk,
               dataIn  => disableFull,
               dataOut => disableFullS );

  --
  --  While the downstream partner asserts full, don't start a new packet
  --
  comb : process (r, pgpRst, pgpObMaster, pgpTxSlaves, full, holdoffSofS, disableFullS) is
    variable v : RegType;
    variable fullq : sl;
  begin
    v := r;
    v.opCode := '0';
    v.count  := r.count+1;
    
    pgpTxMasters(0) <= pgpObMaster;
    fullq    := full and not disableFullS;
    
    --
    --  I think I need this to prevent AxiResize from misaligning data
    --  on the receive end, but it introduces the possibility of
    --  overflowing buffers on the receive side.  (Fix the receive side)
    --
    if holdoffSofS = '1' then
      if (fullq = '0' or r.tLast = '0') then
        if pgpObMaster.tValid = '1' and pgpTxSlaves(0).tReady = '1' then
          v.tLast                := pgpObMaster.tLast;
        end if;
        pgpTxMasters(0).tValid   <= pgpObMaster.tValid;
        pgpObSlave.tReady        <= pgpTxSlaves(0).tReady;
      else
        pgpTxMasters(0).tValid   <= '0';
        pgpObSlave.tReady        <= '0';
      end if;
    else
      if fullq = '0' then
        pgpTxMasters(0).tValid   <= pgpObMaster.tValid;
        pgpObSlave.tReady        <= pgpTxSlaves(0).tReady;
      else
        pgpTxMasters(0).tValid   <= '0';
        pgpObSlave.tReady        <= '0';
      end if;
    end if;

    if r.count = 0 then
      v.opCode := '1';
    end if;
    
    if pgpRst = '1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;
  end process;

  seq : process (pgpClk) is
  begin
    if rising_edge(pgpClk) then
      r <= rin;
    end if;
  end process seq;
  
end top_level_app;
