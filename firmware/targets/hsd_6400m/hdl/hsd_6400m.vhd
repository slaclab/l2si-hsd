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
 
library work;
use work.QuadAdcPkg.all;
use work.FmcPkg.all;  -- jesd204b component declaration
use work.Jesd204bPkg.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.Pgp3Pkg.all;
use surf.I2cPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
 
library unisim;            
use unisim.vcomponents.all;  

library xil_defaultlib;
  use xil_defaultlib.types_pkg.all;

entity hsd_6400m is
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
     -- PGP Ports (to DRP)
    pgpRefClkP : in    sl;            -- 156.25 MHz
    pgpRefClkN : in    sl;            -- 156.25 MHz
    pgpRxP     : in    slv(7 downto 0);
    pgpRxN     : in    slv(7 downto 0);
    pgpTxP     : out   slv(7 downto 0);
    pgpTxN     : out   slv(7 downto 0);
    pgpFabClkP : in    sl;            -- 156.25 MHz 
    pgpFabClkN : in    sl;

    oe_osc     : out   sl;
    qsfpPrsN   : in    slv(1 downto 0);
    qsfpIntN   : in    slv(1 downto 0);
    qsfpRstN   : out   slv(1 downto 0);
    qsfpSda    : inout slv(1 downto 0);
    qsfpScl    : inout slv(1 downto 0);

    --pgpClkEn   : out   sl;
    --usrClkEn   : out   sl;
    --usrClkSel  : out   sl;
    --qsfpRstN   : out   sl;
    -- ADC Interface
    lmk_out_p      : in    slv(3 downto 2);
    lmk_out_n      : in    slv(3 downto 2);

    pllRefClk      : out   sl;
    
    ext_trigger_p    : in    sl;
    ext_trigger_n    : in    sl;
    
    --sync_from_fpga_p : out   sl;
    --sync_from_fpga_n : out   sl;
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
end hsd_6400m;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of hsd_6400m is

  --  Set timing specific clock parameters
  constant LCLSII_C : boolean := true;
  constant NFMC_C : integer := 2;
  
  signal regReadMaster  : AxiLiteReadMasterType;
  signal regReadSlave   : AxiLiteReadSlaveType;
  signal regWriteMaster : AxiLiteWriteMasterType;
  signal regWriteSlave  : AxiLiteWriteSlaveType;
  signal sysClk, sysRst : sl;
  signal regClk, regRst : sl;
  signal adcRst         : sl;
  signal dmaClk         : sl;
  signal dmaRst         : slv(NFMC_C-1 downto 0);
  signal pllClk, pllRst : sl;
  signal pllLocked      : sl;
  
  signal timingRefClk     : sl;
  signal timingRefClkCopy : sl;
  signal timingRefClkGt   : sl;
  signal timingRecClk   : sl;
  signal timingRecClkRst: sl;
  signal timingBus      : TimingBusType;
  signal timingFbClk    : sl;
  signal timingFbRst    : sl;
  signal timingFb       : TimingPhyType;

  signal dmaIbMaster    : AxiStreamMasterArray(NFMC_C-1 downto 0);
  signal dmaIbSlave     : AxiStreamSlaveArray (NFMC_C-1 downto 0);
  signal fmcClk         : slv                 (NFMC_C-1 downto 0);
  
  signal mDmaMaster    : AxiStreamMasterArray(7 downto 0);
  signal mDmaSlave     : AxiStreamSlaveArray (7 downto 0);

  signal pgpRefClk : sl;
  signal pgpRefClkCopy, pgpCoreClk : sl;
  signal intFabClk, pgpFabClk : sl;
  signal pgpIbMaster         : AxiStreamMasterType;
  signal pgpIbSlave          : AxiStreamSlaveType;
  signal pgpTxMasters        : AxiStreamMasterArray   (7 downto 0);
  signal pgpTxSlaves         : AxiStreamSlaveArray    (7 downto 0);

  constant MMCM_INDEX_C      : integer := 0;
  constant JESD_INDEX_C      : integer := 1;
  constant CHIP_INDEX_C      : integer := 2;
  constant PGP_INDEX_C       : integer := 3;
  constant EXT_INDEX_C       : integer := 4;
  constant QSFP_INDEX_C      : integer := 5;
  constant SURF_JESD_INDEX_C : integer := 7;
  constant TEM_INDEX_C       : integer := 9;
  
  constant NUM_AXI_MASTERS_C : integer := 10;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    MMCM_INDEX_C      => (
      baseAddr        => x"00208800",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    JESD_INDEX_C      => (
      baseAddr        => x"00208000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    CHIP_INDEX_C      => (
      baseAddr        => x"00200000",
      addrBits        => 15,
      connectivity    => x"FFFF"),
    PGP_INDEX_C       => (
      baseAddr        => x"00210000",
      addrBits        => 15,
      connectivity    => x"FFFF"),
    EXT_INDEX_C       => (
      baseAddr        => x"00218000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    QSFP_INDEX_C+0    => (
      baseAddr        => x"00219000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    QSFP_INDEX_C+1    => (
      baseAddr        => x"0021A000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    SURF_JESD_INDEX_C+0 => (
      baseAddr        => x"0021B000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    SURF_JESD_INDEX_C+1 => (
      baseAddr        => x"0021B800",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    TEM_INDEX_C       => (
      baseAddr        => x"00220000",
      addrBits        => 16,
      connectivity    => x"FFFF") );

  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  constant PGP_AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(7 downto 0) := genAxiLiteConfig( 8, x"00090000", 15, 12 );

  signal mPgpAxilWriteMasters : AxiLiteWriteMasterArray(7 downto 0);
  signal mPgpAxilWriteSlaves  : AxiLiteWriteSlaveArray (7 downto 0);
  signal mPgpAxilReadMasters  : AxiLiteReadMasterArray (7 downto 0);
  signal mPgpAxilReadSlaves   : AxiLiteReadSlaveArray  (7 downto 0);

  constant QSFP_DEVICE_MAP_C : I2cAxiLiteDevArray(0 downto 0) := (
    0 => MakeI2cAxiLiteDevType("1010000", 8, 8, '0' ) );

    type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
    --pgpClkEn  : sl;
    --usrClkEn  : sl;
    --usrClkSel : sl;
    oe_osc    : sl;
    qsfpRstN  : sl;
    qpllrst   : sl;
    pgpTxRst  : sl;
    pgpRxRst  : sl;
    pgpHoldoffSof : sl;
    pgpDisableFull : slv(1 downto 0);
    txId      : slv(15 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    --pgpClkEn  => '1',
    --usrClkEn  => '0',
    --usrClkSel => '0',
    oe_osc    => '1',
    qsfpRstN  => '1',
    qpllrst   => '0',
    pgpTxRst  => '0',
    pgpRxRst  => '0',
    pgpHoldoffSof  => '0',
    pgpDisableFull  => "00",
    txId      => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  
  signal rx_data_out        : Slv64Array(15 downto 0);
  signal rx_kchar_out       : Slv8Array (15 downto 0);
  signal rx_disparity_out   : Slv8Array (15 downto 0);
  signal rx_invalid_out     : Slv8Array (15 downto 0);
  signal rx_kchar_and       : slv       ( 7 downto 0);
  signal rx_kchar_or        : slv       ( 7 downto 0);
  signal rx_disparity_sum   : slv       (15 downto 0);
  signal rx_invalid_sum     : slv       (15 downto 0);
  signal xcvr_rxrst         : sl;
  signal align_enable       : sl;
  signal xcvr_rdy_out       : slv(15 downto 0);
  signal rx_ready           : sl;
  signal xcvr_status        : slv(31 downto 0);
  signal qpll_lock          : slv(3 downto 0);
  signal rxn_in             : slv(15 downto 0);
  signal rxp_in             : slv(15 downto 0);
  signal refclk_n           : slv(3 downto 0);
  signal refclk_p           : slv(3 downto 0);
  signal gtrefclk00         : slv(3 downto 0);
  signal rxdfetaphold_int   : sl;
  signal rxdfetapovrden_int : sl;
  signal rxdfeagchold_int   : sl;
  signal rxdfelfhold_int    : sl;
  signal rxlpmgchold_int    : sl;
  signal rxlpmhfhold_int    : sl;
  signal rxlpmlfhold_int    : sl;
  signal rxlpmoshold_int    : sl;
  signal rxoshold_int       : sl;
  signal rxcdrhold_int      : sl;
  signal scrambling_en      : sl;
  signal f_align_char       : slv(7 downto 0);
  signal k_lmfc_cnt         : slv(4 downto 0);
  signal sysref_sync_en     : sl;
  signal sw_trigger         : sl;
  signal sw_trigger_en      : sl;
  signal hw_trigger_en      : sl;
  signal fpga_sync_out      : sl;
  signal sysref_pulse       : sl;
  signal sysref_pulse_delay : sl;
  signal sysref_edge        : sl;
  signal syncb              : slv(1 downto 0);
  signal trigSlot           : slv(1 downto 0);
  signal adcValid           : slv(1 downto 0);
  
  signal rx_clk             : sl;
  signal rst_rxclk          : sl;

  signal adc                : AdcDataArray(7 downto 0);
  
  signal qplllock   : Slv2Array(7 downto 0);
  signal qpllclk    : Slv2Array(7 downto 0);
  signal qpllrefclk : Slv2Array(7 downto 0);
  signal qpllrst    : Slv2Array(7 downto 0);
  signal qpllrsti   : Slv2Array(7 downto 0);

  signal test_clocks : slv(15 downto 0);
  signal s_samples   : Slv12Array(39 downto 0);
  
  signal lmk_devclk, lmk_devclk_bufg : sl;
  signal sysref, sysref_bufg : sl;
  signal rx_count   : unsigned(k_lmfc_cnt'range);

  constant NUM_MON_CLKS : integer := 7;
  signal monClk     : slv       (NUM_MON_CLKS-1 downto 0);
  signal monClkRate : Slv32Array(NUM_MON_CLKS-1 downto 0);
  signal monClkLock : slv       (NUM_MON_CLKS-1 downto 0);
  signal monClkFast : slv       (NUM_MON_CLKS-1 downto 0);
  signal monClkSlow : slv       (NUM_MON_CLKS-1 downto 0);
  signal adcORCnt   : SlVectorArray(9 downto 0, 27 downto 0);
  
  -- PCIE DMA unused
  constant DMA_AXIS_CONFIG_C : AxiStreamConfigArray(3 downto 0) := (
    others=> (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 32,
     TDEST_BITS_C  => 0,
     TID_BITS_C    => 0,
     TKEEP_MODE_C  => TKEEP_NORMAL_C,
     TUSER_BITS_C  => 0,
     TUSER_MODE_C  => TUSER_NORMAL_C ));

  signal phaseValue           : Slv16Array(1 downto 0);
  signal phaseCount           : Slv16Array(1 downto 0);
  signal pgpTxId              : Slv32Array(7 downto 0);
  
  constant READOUT_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);

  constant USE_SURF_JESD : boolean := true;

  signal surfAdcData  : sampleDataArray      (15 downto 0);
  signal surfAdcValid : slv                  (15 downto 0);
  signal surfJesdRx   : jesdGtRxLaneTypeArray(15 downto 0);
  signal surfGtReset  : slv                  (15 downto 0);
  signal surfDebug    : Slv11Array           (15 downto 0);
  
  constant DEBUG_C : boolean := false;
  
  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0));
  end component;
-------------------------------------------------------------------------------
-- architecture begin
-------------------------------------------------------------------------------
begin  -- rtl

  GEN_DEBUG : if DEBUG_C generate
      U_ILA : ila_0
        port map ( clk                    => dmaClk,
                   probe0(             0) => rst_rxclk,
                   probe0(  2 downto   1) => syncb,
                   probe0(             3) => sysref_pulse,
                   probe0(             4) => sysref_sync_en,
                   probe0( 16 downto   5) => s_samples(0),
                   probe0( 28 downto  17) => s_samples(1),
                   probe0( 40 downto  29) => s_samples(2),
                   probe0( 52 downto  41) => s_samples(3),
                   probe0( 64 downto  53) => s_samples(4),
                   probe0( 68 downto  65) => (others=>'0'),
                   probe0( 76 downto  69) => surfJesdRx(0).dataK,
                   probe0( 84 downto  77) => surfJesdRx(0).dispErr,
                   probe0( 92 downto  85) => surfJesdRx(0).decErr,
                   probe0(108 downto  93) => rx_disparity_sum,
                   probe0(124 downto 109) => rx_invalid_sum,
                   probe0(188 downto 125) => surfAdcData(0),
                   probe0(204 downto 189) => surfAdcValid,
                   probe0(           205) => surfJesdRx(0).rstDone,
                   probe0(           206) => surfJesdRx(0).cdrStable,
                   probe0(           207) => sysref_edge,
                   probe0(218 downto 208) => surfDebug(0),
                   probe0(255 downto 219) => (others=>'0') );
    
    GEN_LANE : for i in 0 to 15 generate
      rx_disparity_sum(i) <= '0' when rx_disparity_out(i)=0 else '1';
      rx_invalid_sum  (i) <= '0' when rx_invalid_out  (i)=0 else '1';
    end generate;
  end generate;
  
  cpld_eeprom_wp <= '0';

  OBUF_PLLREFCLK : OBUF
    port map ( I   => pllClk,
               O   => pllRefClk );
  
  timingTxDis <= '0';

  adcRst <= '1' when ( regRst='1' or qpll_lock /= x"F") else '0';
  dmaClk <= rx_clk;
  
  test_clocks(0)           <= regClk;
  test_clocks(1)           <= rx_clk;
  test_clocks(2)           <= sysref_bufg;
  test_clocks(3)           <= lmk_devclk_bufg;
--  test_clocks(4)           <= trigger_bufg;
--  test_clocks(8 downto 5)  <= gtrefclk00;
  test_clocks(15 downto 4) <= (others => '0');

  GEN_QSFP_I2C : for i in 0 to 1 generate
    U_I2C : entity surf.AxiI2cRegMaster
      generic map ( DEVICE_MAP_G   => QSFP_DEVICE_MAP_C,
                    AXI_CLK_FREQ_G => 125.0E+6 )
      port map ( scl            => qsfpScl(i),
                 sda            => qsfpSda(i),
                 axiReadMaster  => mAxilReadMasters (QSFP_INDEX_C+i),
                 axiReadSlave   => mAxilReadSlaves  (QSFP_INDEX_C+i),
                 axiWriteMaster => mAxilWriteMasters(QSFP_INDEX_C+i),
                 axiWriteSlave  => mAxilWriteSlaves (QSFP_INDEX_C+i),
                 axiClk         => regClk,
                 axiRst         => regRst );
  end generate;
    
  BUFDS_lmk_devclk : IBUFDS
    port map (
      O   => lmk_devclk,
      I   => lmk_out_p(2),
      IB  => lmk_out_n(2)
      );

  BUFG_lmk_devclk : BUFG
    port map (
      O => lmk_devclk_bufg,
      I => lmk_devclk
      );
  
  BUFDS_sysref : IBUFDS
    port map (
      O   => sysref,
      I   => lmk_out_p(3),
      IB  => lmk_out_n(3)
      );

  BUFG_sysref : BUFG
    port map (
      O => sysref_bufg,
      I => sysref
      );

  -------------------------------------------------------------------------------------
  -- SYSREF internal synchronization
  -- sysref_pulse asserts on the rising edge of sysref_bufg, but deasserts synchronous
  -- to gtrefclk00. This is designed to have a 50% duty cycle.
  -------------------------------------------------------------------------------------
  sysref_pulse_expand : process(gtrefclk00(0), sysref_bufg)
  begin
    if sysref_bufg = '1' then
      sysref_pulse <= '1';
      rx_count <= (others => '0');
    elsif rising_edge(gtrefclk00(0)) then
      rx_count <= rx_count+1;
      if rx_count = unsigned(k_lmfc_cnt) then
        sysref_pulse <= '0';
      end if;
    end if;
  end process;

  -- SYSREF edge detection
  sysref_edge_detect : process(rx_clk)
  begin
    if rising_edge(rx_clk) then
      sysref_pulse_delay <= sysref_pulse;
    end if;
  end process;
  sysref_edge <= not(sysref_pulse_delay) and sysref_pulse;
 
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
      
  U_Core : entity work.AxiPcieQuadAdcCore
    generic map ( AXI_APP_BUS_EN_G => true,
                  ENABLE_DMA_G     => false,
                  BUILD_INFO_G     => BUILD_INFO_G,
                  AXIS_CONFIG_G    => DMA_AXIS_CONFIG_C(0),
                  LCLSII_G         => LCLSII_C )
    port map ( sysClk         => sysClk,
               sysRst         => sysRst,
               -- DMA Interfaces
               dmaClk      (0)=> dmaClk,
               dmaRst      (0)=> '0',
               dmaObMasters   => open,
               dmaObSlaves    => (others=>AXI_STREAM_SLAVE_INIT_C),
               dmaIbMasters(0)=> AXI_STREAM_MASTER_INIT_C,
               dmaIbSlaves (0)=> open,
               -- Application AXI-Lite
               regClk         => regClk,
               regRst         => regRst,
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
               timingRefClk   => timingRefClkGt,
               timingRxP      => timingRxP,
               timingRxN      => timingRxN,
               timingTxP      => timingTxP,
               timingTxN      => timingTxN,
               timingRecClk   => timingRecClk,
               timingRecClkRst=> timingRecClkRst,
               timingBus      => timingBus,
               timingFbClk    => timingFbClk,
               timingFbRst    => timingFbRst,
               timingFb       => timingFb,
               -- PCIE Ports
               pciRstL        => pciRstL,
               pciRefClkP     => pciRefClkP,
               pciRefClkN     => pciRefClkN,
               pciRxP         => pciRxP,
               pciRxN         => pciRxN,
               pciTxP         => pciTxP,
               pciTxN         => pciTxN );

  -----------------------------------
  -- ADC Reference clock generation
  -----------------------------------
  --  929kHz (*200 = 185.7MHz)  => 3.2 GHz
  --  refClk = 185.7/16 = 11.6 MHz
  --  LMX2581 PLL features
  U_MMCM : entity surf.ClockManagerUltraScale
    generic map ( INPUT_BUFG_G       => false,
                  NUM_CLOCKS_G       => 1,
                  CLKIN_PERIOD_G     => 5.37,
                  CLKFBOUT_MULT_F_G  => 6.0,
                  CLKOUT0_DIVIDE_F_G => 12.0 )
    port map ( clkIn      => timingRecClk,
               rstIn      => timingRecClkRst,
               clkOut(0)  => pllClk,
               rstOut(0)  => pllRst,
               locked     => pllLocked,
               axilClk    => regClk,
               axilRst    => regRst,
               axilReadMaster  => mAxilReadMasters (MMCM_INDEX_C),
               axilReadSlave   => mAxilReadSlaves  (MMCM_INDEX_C),
               axilWriteMaster => mAxilWriteMasters(MMCM_INDEX_C),
               axilWriteSlave  => mAxilWriteSlaves (MMCM_INDEX_C) );
  
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
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

-------------------------------------------------------------------------------------
-- FMC134 Register Block. Contains registers for specific fmc134 functionality
-------------------------------------------------------------------------------------
  fmc134_ctrl_inst : entity work.fmc134_ctrl
    port map (
      axilRst           => regRst,
      axilClk           => regClk,
      axilReadMaster    => mAxilReadMasters (JESD_INDEX_C),
      axilReadSlave     => mAxilReadSlaves  (JESD_INDEX_C),
      axilWriteMaster   => mAxilWriteMasters(JESD_INDEX_C),
      axilWriteSlave    => mAxilWriteSlaves (JESD_INDEX_C),

      rst_rxclk         => rst_rxclk,
      rx_clk            => rx_clk,
      clk320            => gtrefclk00(0),

      adc_valid     (0) => surfAdcValid(0),
      adc_valid     (1) => surfAdcValid(4),
      adc_valid     (2) => surfAdcValid(8),
      adc_valid     (3) => surfAdcValid(12),
      scrambling_en     => scrambling_en,
      f_align_char      => f_align_char,
      k_lmfc_cnt        => k_lmfc_cnt,
      status            => xcvr_status,
      xcvr_rxrst        => xcvr_rxrst,
      sysref_sync_en    => sysref_sync_en,
      rxdfeagchold      => rxdfeagchold_int,
      rxdfelfhold       => rxdfelfhold_int,
      rxdfetaphold      => rxdfetaphold_int,
      rxdfetapovrden    => rxdfetapovrden_int,
      rxlpmgchold       => rxlpmgchold_int,
      rxlpmhfhold       => rxlpmhfhold_int,
      rxlpmlfhold       => rxlpmlfhold_int,
      rxlpmoshold       => rxlpmoshold_int,
      rxoshold          => rxoshold_int,
      rxcdrhold         => rxcdrhold_int,
      align_enable      => align_enable,
      pg_m2c            => pg_m2c     (0),
      prsnt_m2c_l       => prsnt_m2c_l(0),
      adc_ora           => adc_ora,
      adc_orb           => adc_orb,
      adc_ncoa          => adc_ncoa,
      adc_ncob          => adc_ncob,
      adc_calstat       => adc_calstat,
      firefly_int       => '0',
      sw_trigger        => sw_trigger,
      sw_trigger_en     => sw_trigger_en,
      hw_trigger_en     => hw_trigger_en,
      fpga_sync_out     => fpga_sync_out,
      test_clocks       => test_clocks
      );

-------------------------------------------------------------------------------------
--  Transceiver Wrapper
-------------------------------------------------------------------------------------
  xcvr_wrapper_inst0 : entity work.xcvr_wrapper
    port map (
      clk_in              => regClk,
      rst_in              => xcvr_rxrst,
      xcvr_status         => xcvr_status,
      xcvr_rdy_out        => xcvr_rdy_out,
      qpll_lock           => qpll_lock,
      align_enable        => align_enable,

      rxdfeagchold_in     => rxdfeagchold_int,
      rxdfelfhold_in      => rxdfelfhold_int,
      rxlpmgchold_in      => rxlpmgchold_int,
      rxlpmhfhold_in      => rxlpmhfhold_int,
      rxlpmlfhold_in      => rxlpmlfhold_int,
      rxlpmoshold_in      => rxlpmoshold_int,
      rxoshold_in         => rxoshold_int,
      rxcdrhold_in        => rxcdrhold_int,
      sysref_pulse        => sysref_pulse,
      sysref_sync_en      => sysref_sync_en,

      rxdfetaphold_in     => rxdfetaphold_int,
      rxdfetapovrden_in   => rxdfetapovrden_int,

      -- RX interface
      rx_clk_out          => rx_clk,
      rx_data_out         => rx_data_out,
      rx_kchar_out        => rx_kchar_out,
      rx_disparity_out    => rx_disparity_out,
      rx_invalid_out      => rx_invalid_out,

      -- External signal
      rxn_in              => rxn_in,
      rxp_in              => rxp_in,
      refclk_n            => refclk_n,
      refclk_p            => refclk_p,
      gtrefclk00_out      => gtrefclk00
      );

  rxn_in   <=      adc_db_n(1) &      adc_da_n(1) &      adc_db_n(0) &      adc_da_n(0);
  rxp_in   <=      adc_db_p(1) &      adc_da_p(1) &      adc_db_p(0) &      adc_da_p(0);
  refclk_n <= adc_refclkb_n(1) & adc_refclka_n(1) & adc_refclkb_n(0) & adc_refclka_n(0);
  refclk_p <= adc_refclkb_p(1) & adc_refclka_p(1) & adc_refclkb_p(0) & adc_refclka_p(0);

  rx_ready  <= uAnd(xcvr_rdy_out);

  GEN_LANE : for i in 0 to 15 generate
    surfJesdRx(i).data      <= rx_data_out     (i);
    surfJesdRx(i).dataK     <= rx_kchar_out    (i);
    surfJesdRx(i).dispErr   <= rx_disparity_out(i);
    surfJesdRx(i).decErr    <= rx_invalid_out  (i);
    surfJesdRx(i).rstDone   <= xcvr_status     (20+i/4);
    surfJesdRx(i).cdrStable <= xcvr_status     (20+i/4);
  end generate;
  rst_rxclk <= surfGtReset(0);
  GEN_JESDRX : for i in 0 to 1 generate
    U_JesdRx : entity work.Jesd204bRx
      generic map ( F_G => 8,
                    K_G => 16,
                    L_G => 8 )
      port map ( axiClk          => regClk,
                 axiRst          => regRst,
                 axilReadMaster  => mAxilReadMasters (SURF_JESD_INDEX_C+i),
                 axilReadSlave   => mAxilReadSlaves  (SURF_JESD_INDEX_C+i),
                 axilWriteMaster => mAxilWriteMasters(SURF_JESD_INDEX_C+i),
                 axilWriteSlave  => mAxilWriteSlaves (SURF_JESD_INDEX_C+i),
                 sampleDataArr_o => surfAdcData      (8*i+7 downto 8*i),
                 dataValidVec_o  => surfAdcValid     (8*i+7 downto 8*i),
                 devClk_i        => rx_clk,
                 devRst_i        => rst_rxclk,
                 sysRef_i        => sysref_edge,
                 r_jesdGtRxArr   => surfJesdRx       (8*i+7 downto 8*i),
                 gtRxReset_o     => surfGtReset      (8*i+7 downto 8*i),
                 rxPowerDown     => open,
                 rxPolarity      => open,
                 nSync_o         => syncb            (i),
                 debug_o         => surfDebug        (8*i+7 downto 8*i) );
  end generate;

  -------------------------------------------------------------------------------------
-- ADC0-ADC3 Out Streams
-------------------------------------------------------------------------------------
  ADC_SAMPLE_PACKING_proc : process(rst_rxclk, rx_clk)
    variable i : integer;
    variable k : integer;
    variable data    : slv       (63 downto 0); -- single lane data
    variable samples : Slv12Array(39 downto 0); -- single frame data
  begin
    if rst_rxclk = '1' then
      for lane in 0 to 7 loop
        adc(lane).data <= (others=>(others=>'0'));
      end loop;
    elsif rising_edge(rx_clk) then
      for k in 0 to 1 loop
        for lane in 0 to 7 loop
          i := k*8+lane;
          data := surfAdcData(i);
          --    Translate samples within each lane to samples in the channel
          for s in 0 to 4 loop
            samples(8*s + lane/4 + 2*(lane mod 4)) := data(63-12*s downto 52-12*s);
          end loop;
        end loop;
        --  For each interleaved channel, deinterleave in a x4 pattern as
        --  the QuadAdcInterleave firmware expects
        for s in 0 to 39 loop
          adc(4*k+(s mod 4)).data(s/4) <= samples(s);
        end loop;
        if k=0 then
          s_samples <= samples;
        end if;
      end loop;
    end if;
  end process;

  U_QuadCore : entity work.DualAdcCore
    generic map ( BASE_ADDR_C => AXI_CROSSBAR_MASTERS_CONFIG_C(CHIP_INDEX_C).baseAddr,
                  TEM_ADDR_C  => AXI_CROSSBAR_MASTERS_CONFIG_C(TEM_INDEX_C).baseAddr,
                  DMA_STREAM_CONFIG_G => READOUT_AXIS_CONFIG_C )
    port map (
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => mAxilWriteMasters(CHIP_INDEX_C),
      axilWriteSlave      => mAxilWriteSlaves (CHIP_INDEX_C),
      axilReadMaster      => mAxilReadMasters (CHIP_INDEX_C),
      axilReadSlave       => mAxilReadSlaves  (CHIP_INDEX_C),
      --
      temAxilWriteMaster  => mAxilWriteMasters(TEM_INDEX_C),
      temAxilWriteSlave   => mAxilWriteSlaves (TEM_INDEX_C),
      temAxilReadMaster   => mAxilReadMasters (TEM_INDEX_C),
      temAxilReadSlave    => mAxilReadSlaves  (TEM_INDEX_C),
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave ,
      -- EVR Ports
      evrClk              => timingRecClk,
      evrRst              => timingRecClkRst,
      evrBus              => timingBus,
      --
      timingFbClk         => timingFbClk,
      timingFbRst         => timingFbRst,
      timingFb            => timingFb,
      -- ADC
      gbClk               => '0',
      adcClk              => rx_clk,
      adcRst              => adcRst,
      adc                 => adc,
      adcValid            => adcValid,
      fmcClk              => fmcClk, -- phase detector input
      --
      trigSlot            => trigSlot );

  adcValid(0)                <= surfAdcValid(0) and surfAdcValid(4);
  adcValid(1)                <= surfAdcValid(8) and surfAdcValid(12);
  sync_to_lmk                <= uOr(trigSlot);
  fmcClk                     <= (others=>rx_clk);

--------------------
-- PGP3 Data Pipe --
--------------------

  IBUFDS_GTE3_Inst : IBUFDS_GTE3
    generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
      REFCLK_ICNTL_RX    => "00")
    port map (
      I     => pgpRefClkP,
      IB    => pgpRefClkN,
      CEB   => '0',
      ODIV2 => pgpRefClkCopy,
      O     => pgpRefClk);  

  BUFG_GT_Inst : BUFG_GT
    port map (
      I       => pgpRefClkCopy,
      CE      => '1',
      CEMASK  => '1',
      CLR     => '0',
      CLRMASK => '1',
      DIV     => "000",
      O       => pgpCoreClk);

  U_QPLL1 : entity work.Pgp3GthUs186Qpll
    generic map ( TPD_G      => 1 ns,
                  EN_DRP_G   => false )
    port map (
      stableClk  => regClk,
      stableRst  => regRst,
      --
      pgpRefClk  => pgpRefClk ,
      qpllLock   => qplllock  (3 downto 0),
      qpllClk    => qpllclk   (3 downto 0),
      qpllRefClk => qpllrefclk(3 downto 0),
      qpllRst    => qpllrsti  (3 downto 0) );

  U_QPLL2 : entity work.Pgp3GthUs186Qpll
    generic map ( TPD_G      => 1 ns,
                  EN_DRP_G   => false )
    port map (
      stableClk  => regClk,
      stableRst  => regRst,
      --
      pgpRefClk  => timingRefClkGt ,
      qpllLock   => qplllock  (7 downto 4),
      qpllClk    => qpllclk   (7 downto 4),
      qpllRefClk => qpllrefclk(7 downto 4),
      qpllRst    => qpllrsti  (7 downto 4) );

  U_IBUFDS_PGP : IBUFDS
    port map (
      I     => pgpFabClkP,
      IB    => pgpFabClkN,
      O     => intFabClk);

  U_BUFG_PGPFAB : BUFG
    port map ( I => intFabClk,
               O => pgpFabClk );

  U_PGP_ILV : entity work.AxiStreamInterleave
    generic map ( LANES_G        => 4,
                  SAXIS_CONFIG_G => DMA_AXIS_CONFIG_C(0),
                  MAXIS_CONFIG_G => PGP3_AXIS_CONFIG_C )
    port map ( axisClk     => dmaClk,
               axisRst     => dmaRst     (0),
               sAxisMaster => dmaIbMaster(0),
               sAxisSlave  => dmaIbSlave (0),
               mAxisMaster => mDmaMaster(3 downto 0),
               mAxisSlave  => mDmaSlave (3 downto 0));

  U_PGP2_ILV : entity work.AxiStreamInterleave
    generic map ( LANES_G        => 4,
                  SAXIS_CONFIG_G => DMA_AXIS_CONFIG_C(0),
                  MAXIS_CONFIG_G => PGP3_AXIS_CONFIG_C )
    port map ( axisClk     => dmaClk,
               axisRst     => dmaRst     (1),
               sAxisMaster => dmaIbMaster(1),
               sAxisSlave  => dmaIbSlave (1),
               mAxisMaster => mDmaMaster(7 downto 4),
               mAxisSlave  => mDmaSlave (7 downto 4) );
  
  --------------------------
  -- AXI-Lite: Crossbar Core
  --------------------------
  U_XBAR_PGP : entity surf.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => PGP_AXI_CROSSBAR_MASTERS_CONFIG_C'length,
      MASTERS_CONFIG_G   => PGP_AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => regClk,
      axiClkRst        => regRst,
      sAxiWriteMasters(0) => mAxilWriteMasters(PGP_INDEX_C),
      sAxiWriteSlaves (0) => mAxilWriteSlaves (PGP_INDEX_C),
      sAxiReadMasters (0) => mAxilReadMasters (PGP_INDEX_C),
      sAxiReadSlaves  (0) => mAxilReadSlaves  (PGP_INDEX_C),
      mAxiWriteMasters    => mPgpAxilWriteMasters,
      mAxiWriteSlaves     => mPgpAxilWriteSlaves,
      mAxiReadMasters     => mPgpAxilReadMasters,
      mAxiReadSlaves      => mPgpAxilReadSlaves);

  GEN_PGP : for i in 0 to 7 generate
    qpllrsti(i)(1) <= '0';
    qpllrsti(i)(0) <= qpllrst(i)(0) or r.qpllrst;
    pgpTxId (i)(31 downto 0) <= x"fc" & toSlv(i,8) & r.txId;
    U_Pgp : entity work.Pgp3Hsd
      generic map ( ID_G             => toSlv(3*16+i,8),
                    AXIL_BASE_ADDR_G => PGP_AXI_CROSSBAR_MASTERS_CONFIG_C(i).baseAddr,
                    AXIS_CONFIG_G    => PGP3_AXIS_CONFIG_C )
      port map ( coreClk         => '0',  -- unused
                 coreRst         => '0',
                 pgpRxP          => pgpRxP(i),
                 pgpRxN          => pgpRxN(i),
                 pgpTxP          => pgpTxP(i),
                 pgpTxN          => pgpTxN(i),
                 fifoRst         => dmaRst(i/4),
                 --
                 qplllock        => qplllock  (i)(0),
                 qplloutclk      => qpllclk   (i)(0),
                 qplloutrefclk   => qpllrefclk(i)(0),
                 qpllRst         => qpllrst   (i)(0),
                 --
                 axilClk         => regClk,
                 axilRst         => regRst,
                 axilReadMaster  => mPgpAxilReadMasters (i),
                 axilReadSlave   => mPgpAxilReadSlaves  (i),
                 axilWriteMaster => mPgpAxilWriteMasters(i),
                 axilWriteSlave  => mPgpAxilWriteSlaves (i),
                 holdoffSof      => r.pgpHoldoffSof,
                 disableFull     => r.pgpDisableFull(i/4),
                 --
                 --  App Interface
                 ibRst           => dmaRst(i/4),
                 linkUp          => open,
                 rxErr           => open,
                 rxReset         => r.pgpRxRst,
                 --
                 obClk           => dmaClk,
                 obMaster        => mDmaMaster(i),
                 obSlave         => mDmaSlave (i),
                 txReset         => r.pgpTxRst,
                 txId            => pgpTxId   (i),
                 --
                 ibClk           => dmaClk );
  end generate;

  monClk <= timingRefClk & pgpCoreClk & gtrefclk00(0) & lmk_devclk_bufg & sysref_bufg & rx_clk & pllClk;
  
  GEN_MONCLK : for i in 0 to NUM_MON_CLKS-1 generate
    U_MONCLK0 : entity surf.SyncClockFreq
      generic map ( REF_CLK_FREQ_G => 125.0E+6,
                    COMMON_CLK_G   => true,
                    CLK_LOWER_LIMIT_G =>  95.0E+6,
                    CLK_UPPER_LIMIT_G => 255.0E+6 )
      port map ( freqOut     => monClkRate(i),
                 freqUpdated => open,
                 locked      => monClkLock(i),
                 tooFast     => monClkFast(i),
                 tooSlow     => monClkSlow(i),
                 clkIn       => monClk(i),
                 locClk      => regClk,
                 refClk      => regClk );
  end generate;

  U_TRIGRATE : entity surf.SyncTrigRateVector
    generic map ( REF_CLK_FREQ_G => 125.0E+6,
                  COMMON_CLK_G   => true,
                  CNT_WIDTH_G    => 28,
                  WIDTH_G        => 10 )
    port map ( trigIn(0)      => adc_ora(0)(0),
               trigIn(1)      => adc_ora(0)(1),
               trigIn(2)      => adc_orb(0)(0),
               trigIn(3)      => adc_orb(0)(1),
               trigIn(4)      => adc_ora(1)(0),
               trigIn(5)      => adc_ora(1)(1),
               trigIn(6)      => adc_orb(1)(0),
               trigIn(7)      => adc_orb(1)(1),
               trigIn(8)      => adc_calstat(0),
               trigIn(9)      => adc_calstat(1),
               trigRateOut    => adcORCnt,
               locClk         => regClk,
               refClk         => regClk );

  U_ADC_PHASE : entity work.PhaseDetector
    generic map ( WIDTH_G => 16 )
    port map ( stableClk  => regClk,
               latch      => '0',
               refClk     => rx_clk,
               refClkRst  => rst_rxclk,
               testClk    => timingRecClk,
               testClkRst => timingRecClkRst,
               testSync   => timingBus.strobe,
               testId     => timingBus.message.pulseId(0),
               ready      => open,
               phase0     => phaseValue(0),
               phase1     => phaseValue(1),
               count0     => phaseCount(0),
               count1     => phaseCount(1),
               valid      => open );

  
  comb : process ( r, regRst, pg_m2c, prsnt_m2c_l, qsfpPrsN, qsfpIntN, mAxilReadMasters, mAxilWriteMasters,
                   monClkRate, monClkLock, monClkFast, monClkSlow, adcORCnt, phaseCount, phaseValue ) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn(ep, mAxilWriteMasters(EXT_INDEX_C), mAxilReadMasters(EXT_INDEX_C), v.axilWriteSlave, v.axilReadSlave);
    ep.axiReadSlave.rdata := (others=>'0');

    axiSlaveRegisterR( ep, toSlv(0,12),  0, prsnt_m2c_l(1));
    axiSlaveRegisterR( ep, toSlv(0,12),  1, pg_m2c     (1));
    axiSlaveRegisterR( ep, toSlv(0,5),  2, qsfpPrsN      );
    axiSlaveRegisterR( ep, toSlv(0,5),  4, qsfpIntN      );
    --axiSlaveRegister ( ep, toSlv(4,12),  0, v.pgpClkEn );
    --axiSlaveRegister ( ep, toSlv(4,12),  1, v.usrClkEn );
    --axiSlaveRegister ( ep, toSlv(4,12),  2, v.usrClkSel);
    --axiSlaveRegister ( ep, toSlv(4,12),  3, v.qsfpRstN);
    axiSlaveRegister ( ep, toSlv(4,12),  0, v.oe_osc);
    axiSlaveRegister ( ep, toSlv(4,12),  3, v.qsfpRstN);
    axiSlaveRegister ( ep, toSlv(4,12),  4, v.qpllrst);
    axiSlaveRegister ( ep, toSlv(4,12),  5, v.pgpTxRst);
    axiSlaveRegister ( ep, toSlv(4,12),  6, v.pgpRxRst);
    axiSlaveRegister ( ep, toSlv(4,12),  7, v.pgpHoldoffSof);
    axiSlaveRegister ( ep, toSlv(4,12),  8, v.pgpDisableFull);

    for i in 0 to NUM_MON_CLKS-1 loop
      axiSlaveRegisterR( ep, toSlv(4*i+8,12), 0, monClkRate(i)(28 downto 0));
      axiSlaveRegisterR( ep, toSlv(4*i+8,12),29, monClkSlow(i));
      axiSlaveRegisterR( ep, toSlv(4*i+8,12),30, monClkFast(i));
      axiSlaveRegisterR( ep, toSlv(4*i+8,12),31, monClkLock(i));
    end loop;

    for i in 0 to 9 loop
      axiSlaveRegisterR( ep, toSlv(4*i+36,12), 0, muxSlVectorArray(adcORCnt, i));
    end loop;

    for i in 0 to 1 loop
      axiSlaveRegisterR( ep, toSlv(8*i+76,12), 0, phaseCount(i));
      axiSlaveRegisterR( ep, toSlv(8*i+80,12), 0, phaseValue(i));
    end loop;

    axiSlaveRegister ( ep, toSlv(92,12), 0, v.txId);
    
    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    if regRst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    mAxilWriteSlaves(EXT_INDEX_C) <= r.axilWriteSlave;
    mAxilReadSlaves (EXT_INDEX_C) <= r.axilReadSlave;
    --pgpClkEn    <= r.pgpClkEn ;
    --usrClkEn    <= r.usrClkEn ;
    --usrClkSel   <= r.usrClkSel;
    qsfpRstN(0)   <= r.qsfpRstN;
    qsfpRstN(1)   <= r.qsfpRstN;
  end process;

  seq: process ( regClk ) is
  begin
    if rising_edge(regClk) then
      r <= r_in;
    end if;
  end process;

  
  -------------------------------------------------------------------------------------
-- Connect Port Signals
-------------------------------------------------------------------------------------

  adc_syncse_n <= syncb;

  
  --sync_to_lmk   <= fpga_sync_out;
  --fmc_aclk      <= rx_clk;
  --fmc_aresetn   <= not rst_rxclk;

  --OBUFDS_sync : OBUFDS
  --  port map (
  --    O  => sync_from_fpga_p,
  --    OB => sync_from_fpga_n,
  --    I  => fpga_sync_out
  --    );

end rtl;
