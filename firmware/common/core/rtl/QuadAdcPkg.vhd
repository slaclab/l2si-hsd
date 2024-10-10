-------------------------------------------------------------------------------
-- Title : top poject package
-- Poject : quad_demo
-------------------------------------------------------------------------------
-- File : quad_demo_top_pkg.vhd
-- Autho : FARCY G.
-- Compagny : e2v
-- Last update : 2009/04/06
-- Platefom :
-------------------------------------------------------------------------------
-- Desciption : define some signals type used in others files of the projectx 
-------------------------------------------------------------------------------
-- Revision :
-- Date         Vesion      Author         Description
-- 2009/04/06   1.0          FARCY G.       Ceated
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- libary description
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.FexAlgPkg.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

use work.FmcPkg.all;
use work.FexAlgPkg.all;

package QuadAdcPkg is
  constant DMA_CHANNELS_C : natural := 5;  -- 4 ADC channels + 1 monitor channel
-------------------------------------------------------------------------------
--  Constants to configue in function of ADC witch is targeted
-------------------------------------------------------------------------------
  constant PATTERN_WIDTH          : natural := 11; --number of bits by channel 
  constant CHANNELS_C         : natural := 8;  -- number of channel FIXE DONT CHANGE
                                               -- Wite in nb_channel register with SPI register to configure channel number 
  constant SERDES_FACTOR    : natural := 8;  --deserialization factor in SERDES

  type serdes_tap_value_type is array (CHANNELS_C-1 downto 0) of NaturalArray(PATTERN_WIDTH - 1 downto 0);
  constant SERDES_TAP_VALUE : serdes_tap_value_type := (others=>(others=>0));

  constant Q_NONE  : slv(1 downto 0) := "00";
  constant Q_ABCD  : slv(1 downto 0) := "01";
  constant Q_AC_BD : slv(1 downto 0) := "10";

  type AdcInput is record
    clkp  : sl;
    clkn  : sl;
    datap : slv(10 downto 0);
    datan : slv(10 downto 0);
  end record;

  type AdcInputArray is array (natural range <>) of AdcInput;

  type AdcData is record
    data : AdcWordArray(ROW_SIZE-1 downto 0);
  end record;
  
  constant ADC_DATA_INIT_C : AdcData := (
    data => (others=>(others=>'0')) );

  type AdcDataArray is array(natural range<>) of AdcData;

  constant MAX_STREAMS_C : integer := 5;
  subtype STREAMS_RG is natural range MAX_STREAMS_C-1 downto 0;
  type FexConfigType is record
    fexEnable    : slv       (STREAMS_RG);
    fexPrescale  : Slv10Array(STREAMS_RG);
    fexPreCount  : Slv10Array(STREAMS_RG);
    fexBegin     : Slv14Array(STREAMS_RG);
    fexLength    : Slv14Array(STREAMS_RG);
    aFull        : Slv16Array(STREAMS_RG);
    aFullN       : Slv5Array (STREAMS_RG);
  end record;

  constant FEX_CONFIG_INIT_C : FexConfigType := (
    fexEnable    => (others=>'0'),
    fexPrescale  => (others=>(others=>'0')),
    fexPreCount  => (others=>(others=>'0')),
    fexBegin     => (others=>(others=>'0')),
    fexLength    => (others=>(others=>'0')),
    aFull        => (others=>(others=>'0')),
    aFullN       => (others=>(others=>'0')) );

  type FexConfigArray is array(natural range<>) of FexConfigType;

  type FexStatusType is record
    free  : slv(15 downto 0);
    nfree : slv( 4 downto 0);
  end record;

  constant FEX_STATUS_INIT_C : FexStatusType := (
    free  => (others=>'0'),
    nfree => (others=>'0') );

  type FexStatusArray is array(natural range<>) of FexStatusType;
  
  --
  --  Event Buffer Handling
  --
--  constant RAM_DEPTH_C : integer := 8192; -- fails by 0.26 ns
--  constant RAM_DEPTH_C : integer := 4096;
--  constant RAM_DEPTH_C : integer := 2048;
  constant MAX_OVL_C : integer := 16;
  constant MAX_OVL_BITS_C : integer := bitSize(MAX_OVL_C-1);
  constant IDX_BITS : integer := bitSize(ROW_SIZE-1);
  constant RAM_ADDR_WIDTH_C : integer := bitSize(RAM_DEPTH_C-1);
  constant CACHE_ADDR_LEN_C : integer := RAM_ADDR_WIDTH_C+IDX_BITS;
  constant SKIP_CHAR : slv(1 downto 0) := "10";
  constant CACHETYPE_LEN_C : integer := 33 + 2*IDX_BITS+2*CACHE_ADDR_LEN_C;
  
  type CacheStateType is ( EMPTY_S,  -- buffer empty
                           OPEN_S,   -- buffer filling
                           CLOSED_S, -- buffer filled
                           READING_S,-- buffer emptying
                           LAST_S ); -- last word to empty
  type TrigStateType is ( WAIT_T,     -- awaiting trigger/veto information
                          ACCEPT_T,   -- event accepted
                          REJECT_T ); -- event vetoed
  type MapStateType is ( BEGIN_M,     -- seeking first address in RAM
                         END_M,       -- seeking last address in RAM
                         DONE_M );    -- all addresses known
  
  type CacheType is record
    state  : CacheStateType;
    trigd  : TrigStateType;
    toffs  : slv(15 downto 0);
    boffs  : slv(IDX_BITS-1 downto 0);
    eoffs  : slv(IDX_BITS-1 downto 0);
    baddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
    eaddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
    tag    : slv(4 downto 0);
    drows  : integer range 0 to ROW_SIZE*RAM_DEPTH_C-1;
--    didxs  : integer range 1-ROW_SIZE to ROW_SIZE-1;
    didxs  : integer range 1-ROW_SIZE*RAM_DEPTH_C to ROW_SIZE*RAM_DEPTH_C-1;
    valid  : sl;
    skip   : sl;
    ovflow : sl;
    oor    : sl;
  end record;
  constant CACHE_INIT_C : CacheType := (
    state  => EMPTY_S,
    trigd  => WAIT_T,
    toffs  => (others=>'0'),
    boffs  => (others=>'0'),
    eoffs  => (others=>'0'),
    baddr  => (others=>'0'),
    eaddr  => (others=>'0'),
    tag    => (others=>'0'),
    drows  => 0,
    didxs  => 0,
    valid  => '0',
    skip   => '0',
    ovflow => '0',
    oor    => '0');
  
  type CacheArray is array(natural range<>) of CacheType;
  type CacheStatusArray is array(natural range<>) of CacheArray(MAX_OVL_C-1 downto 0);

  function cacheToSlv  (status : CacheType) return slv;
  function toCacheType (vector : slv)      return CacheType;

  constant BUILD_STATUS_LEN_C : integer := 10;
  type BuildStatusType is record
    state   : slv(2 downto 0);
    dumps   : slv(3 downto 0);
    hdrv    : sl;
    valid   : sl;
    ready   : sl;
  end record;
  
  constant QADC_STATUS_TYPE_LEN_C : integer := 32*5+32+MAX_STREAMS_C*MAX_OVL_C*CACHETYPE_LEN_C+BUILD_STATUS_LEN_C;
  type QuadAdcStatusType is record
    eventCount    : Slv32Array(4 downto 0);
    dmaCtrlCount  : slv(31 downto 0);
    eventCache    : CacheStatusArray(MAX_STREAMS_C-1 downto 0);
    build         : BuildStatusType;
  end record;

  constant QADC_CONFIG_TYPE_LEN_C : integer := CHANNELS_C+124;
  type QuadAdcConfigType is record
    enable    : slv(CHANNELS_C-1 downto 0);  -- channel mask
    partition : slv( 2 downto 0);  -- LCLS: not used
    intlv     : slv( 1 downto 0);
    samples   : slv(17 downto 0);
    prescale  : slv( 5 downto 0);  -- subsampling factor
    offset    : slv(19 downto 0);  -- delay, clks
    acqEnable : sl;                -- enable per FMC
    rateSel   : slv(12 downto 0);  -- LCLS: eventCode
    destSel   : slv(18 downto 0);  -- LCLS: not used
    inhibit   : sl;
    dmaTest   : sl;
    trigShift : slv( 7 downto 0);
    localId   : slv(31 downto 0);
  end record;
  constant QUAD_ADC_CONFIG_INIT_C : QuadAdcConfigType := (
    enable    => (others=>'0'),
    partition => (others=>'0'),
    intlv     => Q_NONE,
    samples   => toSlv(0,18),
    prescale  => toSlv(1,6),
    offset    => toSlv(0,20),
    acqEnable => '0',
    rateSel   => (others=>'0'),
    destSel   => (others=>'0'),
    inhibit   => '1',
    dmaTest   => '0',
    trigShift => (others=>'0'),
    localId   => (others=>'0') );

  type BRamWriteMasterType is record
    en    : sl;
    addr  : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    data  : slv(16*ROW_SIZE-1 downto 0);
  end record;

  constant BRAM_WRITE_MASTER_INIT_C : BRamWriteMasterType := (
    en    => '0',
    addr  => (others=>'0'),
    data  => (others=>'0') );

  type BRamWriteMasterArray is array(natural range<>) of BRamWriteMasterType;
  
  type BRamReadMasterType is record
    en    : sl;
    addr  : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  end record;

  constant BRAM_READ_MASTER_INIT_C : BRamReadMasterType := (
    en    => '0',
    addr  => (others=>'0') );

  type BRamReadMasterArray is array(natural range<>) of BRamReadMasterType;
  
  type BRamReadSlaveType is record
    data  : slv(16*ROW_SIZE-1 downto 0);
  end record;

  constant BRAM_READ_SLAVE_INIT_C : BRamReadSlaveType := (
    data  => (others=>'0') );

  type BRamReadSlaveArray is array(natural range<>) of BRamReadSlaveType;

  constant QUAD_ADC_EVENT_TAG : slv(15 downto 0) := X"0000";
  constant QUAD_ADC_DIAG_TAG  : slv(15 downto 0) := X"0001";

  procedure assignSlv   (i : inout integer; vector: inout slv; value : in    CacheArray);
  procedure assignRecord(i : inout integer; vector: in    slv; value : inout CacheArray);
  
  function toSlv       (config : QuadAdcConfigType) return slv;
  function toQadcConfig(vector : slv)               return QuadAdcConfigType;
  function toSlv       (status : QuadAdcStatusType) return slv;
  function toQadcStatus(vector : slv)               return QuadAdcStatusType;
  function hsdTimingFbId(localId : slv) return slv;
  
end QuadAdcPkg;

package body QuadAdcPkg is

  procedure assignSlv(
    i      : inout integer;
    vector : inout slv;
    value  : in    CacheArray)
  is
    variable low : integer;
  begin
    for j in 0 to MAX_OVL_C-1 loop
      low := i;
      i   := i+CACHETYPE_LEN_C;
      vector(i-1 downto low) := cacheToSlv(value(j));
    end loop;
  end procedure assignSlv;

  procedure assignRecord(
    i      : inout integer;
    vector : in    slv;
    value  : inout CacheArray)
  is
    variable low : integer;
  begin
    for j in 0 to MAX_OVL_C-1 loop
      low := i;
      i   := i+CACHETYPE_LEN_C;
      value(j) := toCacheType(vector(i-1 downto low));
    end loop;
  end procedure assignRecord;
  
  function toSlv (config : QuadAdcConfigType) return slv
  is
    variable vector : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0) := (others => '0');
    variable i      : integer                               := 0;
  begin
    assignSlv(i, vector, config.enable);
    assignSlv(i, vector, config.partition);
    assignSlv(i, vector, config.intlv);
    assignSlv(i, vector, config.samples);
    assignSlv(i, vector, config.prescale);
    assignSlv(i, vector, config.offset);
    assignSlv(i, vector, config.acqEnable);
    assignSlv(i, vector, config.rateSel);
    assignSlv(i, vector, config.destSel);
    assignSlv(i, vector, config.inhibit);
    assignSlv(i, vector, config.dmaTest);
    assignSlv(i, vector, config.trigShift);
    assignSlv(i, vector, config.localId);
    return vector;
  end function;
  
  function toQadcConfig (vector : slv) return QuadAdcConfigType
  is
    variable config : QuadAdcConfigType;
    variable i       : integer := 0;
  begin
    assignRecord(i, vector, config.enable);
    assignRecord(i, vector, config.partition);
    assignRecord(i, vector, config.intlv);
    assignRecord(i, vector, config.samples);
    assignRecord(i, vector, config.prescale);
    assignRecord(i, vector, config.offset);
    assignRecord(i, vector, config.acqEnable);
    assignRecord(i, vector, config.rateSel);
    assignRecord(i, vector, config.destSel);
    assignRecord(i, vector, config.inhibit);
    assignRecord(i, vector, config.dmaTest);
    assignRecord(i, vector, config.trigShift);
    assignRecord(i, vector, config.localId);
    return config;
  end function;
  
  function toSlv (status : QuadAdcStatusType) return slv
  is
    variable vector : slv(QADC_STATUS_TYPE_LEN_C-1 downto 0) := (others => '0');
    variable i,j,low    : integer                               := 0;
  begin
    for j in 4 downto 0 loop
        assignSlv(i, vector, status.eventCount(j));
    end loop;
    assignSlv(i, vector, status.dmaCtrlCount);
    for j in 0 to MAX_STREAMS_C-1 loop
      assignSlv(i, vector, status.eventCache(j));
    end loop;
    assignSlv(i, vector, status.build.state);
    assignSlv(i, vector, status.build.dumps);
    assignSlv(i, vector, status.build.hdrv );
    assignSlv(i, vector, status.build.valid);
    assignSlv(i, vector, status.build.ready);
    return vector;
  end function;
  
  function toQadcStatus (vector : slv) return QuadAdcStatusType
  is
    variable status  : QuadAdcStatusType;
    variable i,j,low : integer := vector'low;
  begin
    for j in 4 downto 0 loop
      assignRecord(i, vector, status.eventCount(j));
    end loop;
    assignRecord(i, vector, status.dmaCtrlCount);
    for j in 0 to MAX_STREAMS_C-1 loop
      assignRecord(i, vector, status.eventCache(j));
    end loop;
    assignRecord(i, vector, status.build.state);
    assignRecord(i, vector, status.build.dumps);
    assignRecord(i, vector, status.build.hdrv );
    assignRecord(i, vector, status.build.valid);
    assignRecord(i, vector, status.build.ready);
    return status;
  end function;
  
  function cacheToSlv (status : CacheType) return slv
  is
    variable vector : slv(CACHETYPE_LEN_C-1 downto 0) := (others => '0');
    variable i      : integer                          := 0;
    variable vstate : slv(3 downto 0) := (others=>'0');
    variable vtrigd : slv(3 downto 0) := (others=>'0');
  begin
    case status.state is
      when EMPTY_S   => vstate := x"0";
      when OPEN_S    => vstate := x"1";
      when CLOSED_S  => vstate := x"2";
      when READING_S => vstate := x"3";
      when others    => vstate := x"4";
    end case;
    assignSlv(i, vector, vstate);
    case status.trigd is
      when WAIT_T    => vtrigd := x"0";
      when ACCEPT_T  => vtrigd := x"1";
      when others    => vtrigd := x"2";
    end case;
    assignSlv(i, vector, vtrigd);
    assignSlv(i, vector, status.toffs);
    assignSlv(i, vector, status.boffs);
    assignSlv(i, vector, status.eoffs);
    assignSlv(i, vector, status.baddr);
    assignSlv(i, vector, status.eaddr);
    assignSlv(i, vector, status.tag);
    assignSlv(i, vector, status.valid);
    assignSlv(i, vector, status.skip);
    assignSlv(i, vector, status.ovflow);
    assignSlv(i, vector, status.oor);
    return vector;
  end function;
  
  function toCacheType (vector : slv) return CacheType
  is
    variable status : CacheType := CACHE_INIT_C;
    variable i       : integer := vector'low;
    variable vstate : slv(3 downto 0) := (others=>'0');
    variable vtrigd : slv(3 downto 0) := (others=>'0');
  begin
    assignRecord(i, vector, vstate);
    case vstate is
      when x"0"   => status.state := EMPTY_S;
      when x"1"   => status.state := OPEN_S;
      when x"2"   => status.state := CLOSED_S;
      when x"3"   => status.state := READING_S;
      when others => status.state := LAST_S;
    end case;
    assignRecord(i, vector, vtrigd);
    case vtrigd is
      when x"0"   => status.trigd := WAIT_T;
      when x"1"   => status.trigd := ACCEPT_T;
      when others => status.trigd := REJECT_T;
    end case;
    assignRecord(i, vector, status.toffs);
    assignRecord(i, vector, status.boffs);
    assignRecord(i, vector, status.eoffs);
    assignRecord(i, vector, status.baddr);
    assignRecord(i, vector, status.eaddr);
    assignRecord(i, vector, status.tag);
    assignRecord(i, vector, status.valid);
    assignRecord(i, vector, status.skip);
    assignRecord(i, vector, status.ovflow);
    assignRecord(i, vector, status.oor);
    return status;
  end function;

  function hsdTimingFbId(localId : slv) return slv is
    variable vec : slv(31 downto 0);
  begin
    vec := toSlv(252,8) & localId(23 downto 0);
    return vec;
  end function;

end package body QuadAdcPkg;

