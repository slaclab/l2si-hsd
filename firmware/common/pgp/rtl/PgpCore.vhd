-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp2bPkg.all;

library l2si_core; 

entity PgpCore is
   generic (
      TPD_G               : time                := 1 ns;
      PGP_ID              : slv(7 downto 0)     := (others=>'0');
      AXI_CONFIG_G        : AxiStreamConfigType );
   port (
     coreClk         : in  sl;
     coreRst         : in  sl;
     gtRefClk        : in  sl;
     pgpRxP          : in  sl;
     pgpRxN          : in  sl;
     pgpTxP          : out sl;
     pgpTxN          : out sl;
     fifoRst         : in  sl;
     --
     phyRst          : in  sl;
     txPllRst        : in  sl;
     rxPllRst        : in  sl;
     txPgpRst        : in  sl;
     rxPgpRst        : in  sl;
     --
     axilClk         : in  sl;
     axilRst         : in  sl;
     axilReadMaster  : in  AxiLiteReadMasterType;
     axilReadSlave   : out AxiLiteReadSlaveType;
     axilWriteMaster : in  AxiLiteWriteMasterType;
     axilWriteSlave  : out AxiLiteWriteSlaveType;
     --
     --  App Interface
     ibRst           : in  sl;
     linkUp          : out sl;
     rxErr           : out sl;
     --
     obClk           : in  sl;
     obMaster        : in  AxiStreamMasterType;
     obSlave         : out AxiStreamSlaveType;
     --  DRP Interface (axilClk domain)
     drpaddr_in      : in  slv(8 DOWNTO 0) := (others=>'0');
     drpdi_in        : in  slv(15 DOWNTO 0) := (others=>'0');
     drpen_in        : in  sl := '0';
     drpwe_in        : in  sl := '0';
     drpdo_out       : out slv(15 DOWNTO 0);
     drprdy_out      : out sl );
end PgpCore;

architecture rtl of PgpCore is

  signal pgpObMaster : AxiStreamMasterType;
  signal pgpObSlave  : AxiStreamSlaveType;

  signal pgpClk         : sl;
  signal pgpTxIn        : Pgp2bTxInType;
  signal pgpTxOut       : Pgp2bTxOutType;
  signal pgpRxIn        : Pgp2bRxInType;
  signal pgpRxOut       : Pgp2bRxOutType;
  signal pgpTxMasters   : AxiStreamMasterArray(3 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal pgpTxSlaves    : AxiStreamSlaveArray (3 downto 0);
  signal pgpRxMasters   : AxiStreamMasterArray(3 downto 0);
  signal pgpRxCtrls     : AxiStreamCtrlArray  (3 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

  signal full           : sl;
  
  constant locTxIn : Pgp2bTxInType := (
    flush       => '0',
    opCodeEn    => '0',
    opCode      => (others=>'0'),
    locData     => PGP_ID,
    flowCntlDis => '0',
    resetTx     => '0',
    resetGt     => '0' );

  
begin

  U_Fifo : entity surf.AxiStreamFifoV2
    generic map (
      SLAVE_AXI_CONFIG_G  => AXI_CONFIG_G,
      MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C )
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

  process (pgpObMaster, pgpTxSlaves, full) is
  begin
    pgpTxMasters(0)        <= pgpObMaster;
    pgpTxMasters(0).tValid <= pgpObMaster.tValid and not full;
    pgpObSlave.tReady      <= pgpTxSlaves(0).tReady and not full;
  end process;
  
  U_PgpFb : entity l2si_core.DtiPgpFb
    port map ( pgpClk       => pgpClk,
               pgpRst       => coreRst,
               pgpRxOut     => pgpRxOut,
               rxAlmostFull => full );

  U_Pgp2b : entity l2si_core.MpsPgpFrontEnd
    port map ( pgpClk       => pgpClk,
               pgpRst       => coreRst,
               stableClk    => axilClk,
               gtRefClk     => gtRefClk,
               txOutClk     => pgpClk,
               --
               pgpTxIn      => pgpTxIn,
               pgpTxOut     => pgpTxOut,
               pgpRxIn      => pgpRxIn,
               pgpRxOut     => pgpRxOut,
               --
               --phyRst       => phyRst,
               --txPllRst     => txPllRst,
               --rxPllRst     => rxPllRst,
               --txPgpRst     => txPgpRst,
               --rxPgpRst     => rxPgpRst,
               -- Frame TX Interface
               pgpTxMasters => pgpTxMasters,
               pgpTxSlaves  => pgpTxSlaves,
               -- Frame RX Interface
               pgpRxMasters => pgpRxMasters,
               pgpRxCtrl    => pgpRxCtrls,
               -- GT Pins
               gtTxP        => pgpTxP,
               gtTxN        => pgpTxN,
               gtRxP        => pgpRxP,
               gtRxN        => pgpRxN,
               --
               drpaddr_in   => drpaddr_in,
               drpdi_in     => drpdi_in,
               drpen_in     => drpen_in,
               drpwe_in     => drpwe_in,
               drpdo_out    => drpdo_out,
               drprdy_out   => drprdy_out );

  U_Axi : entity surf.Pgp2bAxi
    generic map ( WRITE_EN_G => true )
    port map ( -- TX PGP Interface (pgpTxClk)
               pgpTxClk         => pgpClk,
               pgpTxClkRst      => coreRst,
               pgpTxIn          => pgpTxIn,
               pgpTxOut         => pgpTxOut,
               locTxIn          => locTxIn,
               -- RX PGP Interface (pgpRxClk)
               pgpRxClk         => pgpClk,
               pgpRxClkRst      => coreRst,
               pgpRxIn          => pgpRxIn,
               pgpRxOut         => pgpRxOut,
               -- AXI-Lite Register Interface (axilClk domain)
               axilClk          => axilClk,
               axilRst          => axilRst,
               axilReadMaster   => axilReadMaster,
               axilReadSlave    => axilReadSlave,
               axilWriteMaster  => axilWriteMaster,
               axilWriteSlave   => axilWriteSlave );
          
end rtl;
