library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity smart_led_driver is
  port
  (
    clock         : in  std_ulogic;
    reset_n       : in  std_ulogic;
    spi_clk_in    : in  std_ulogic;
    spi_mosi_in   : in  std_ulogic;
    spi_cs_in     : in  std_ulogic;
    interrupt_out : out std_ulogic;
    serial_out    : out std_ulogic;
    la_0          : out std_ulogic;
    la_1          : out std_ulogic;
    la_2          : out std_ulogic;
    la_3          : out std_ulogic;
    la_4          : out std_ulogic;
    la_5          : out std_ulogic;
    la_6          : out std_ulogic);
end entity;

architecture rtl of smart_led_driver is

  -- configuration
  constant LED_COUNT      : natural := 246;
  constant N              : natural := LED_COUNT * 3; --> N = number of bytes => N = LED_count*3
  constant CLOCK_FREQ     : natural := 12_000_000; -- system clock
  constant LOW_TIME       : natural := 350; -- ns
  constant HIGH_TIME      : natural := 700; -- ns
  constant TOTAL_TIME     : natural := 1_250; -- ns
  constant RESET_TIME     : natural := 280_000; -- ns

  constant DATA_WIDTH     : natural := 8;
  -- TODO calculate ADDR_WIDTH
  constant ADDR_WIDTH     : natural := 12;

  -- spi_slave x memwriteinterface
  signal spi_data_valid   : std_ulogic;
  signal spi_data         : std_ulogic_vector(7 downto 0);

  -- memwriteinterface x memreadinterface
  signal new_frame        : std_ulogic;

  -- memreadinterface x pwmgen
  signal pwm_data         : std_ulogic_vector(7 downto 0);
  signal pwm_data_valid   : std_ulogic;
  signal pwm_done, pwm_en : std_ulogic;

  -- pwmgen
  signal pwm              : std_ulogic;

  -- memory
  signal mem_wd, mem_rd   : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
  signal mem_wa, mem_ra   : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
  signal mem_we           : std_ulogic;

  -- status
  signal idle             : std_ulogic;

  component pwmgen
    generic
    (
      CLOCK_FREQ : natural;
      HIGH_TIME  : natural;
      LOW_TIME   : natural;
      TOTAL_TIME : natural);
    port
    (
      clk_i  : in  std_ulogic;
      rst_n  : in  std_ulogic;
      d_i    : in  std_ulogic_vector(7 downto 0);
      dv_i   : in  std_ulogic;
      en_i   : in  std_ulogic;
      pwm_o  : out std_ulogic;
      done_o : out std_ulogic);
  end component;

  component memreadinterface
    generic
    (
      CLOCK_FREQ     : natural;
      RESET_TIME     : natural;
      N              : natural;
      MEM_DATA_WIDTH : natural; -- Width of each data word
      MEM_ADDR_WIDTH : natural); -- Address width
    port
    (
      clk_i       : in  std_ulogic;
      rst_n       : in  std_ulogic;
      mem_a_o     : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
      mem_d_i     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
      done_pwm_i  : in  std_ulogic;
      dv_o        : out std_ulogic;
      d_o         : out std_ulogic_vector(7 downto 0);
      en_pwm_o    : out std_ulogic;
      idle_o      : out std_ulogic;
      new_frame_i : in  std_ulogic);
  end component;

  component mem
    port
    (
      clk_i : in  std_ulogic;
      wd_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Write Data
      wa_i  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- Write Address
      we_i  : in  std_ulogic; -- Write Enable
      rd_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Read Data
      ra_i  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0)); -- Read Address 
  end component;

  component memwriteinterface
    generic
    (
      N              : natural;
      MEM_DATA_WIDTH : natural; -- Width of each data word
      MEM_ADDR_WIDTH : natural); -- Address width
    port
    (
      clk_i       : in  std_ulogic;
      rst_n       : in  std_ulogic;
      mem_a_o     : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
      mem_d_o     : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
      mem_we_o    : out std_ulogic;
      dv_i        : in  std_ulogic;
      d_i         : in  std_ulogic_vector(7 downto 0);
      new_frame_o : out std_ulogic;
      spi_cs_i    : in  std_ulogic);

  end component;

  component spi_slave is
    port
    (
      rst_n      : in  std_ulogic;
      spi_cs_i   : in  std_ulogic;
      spi_clk_i  : in  std_ulogic;
      spi_mosi_i : in  std_ulogic;
      dv_o       : out std_ulogic;
      d_o        : out std_ulogic_vector(7 downto 0));
  end component;

begin

  la_0          <= clock;
  la_1          <= mem_we;
  la_2          <= idle;
  la_3          <= new_frame;
  la_4          <= pwm;
  la_5          <= spi_cs_in;
  la_6          <= idle;

  -- signal mapping	
  serial_out    <= pwm;
  interrupt_out <= idle;

  pwmgen_i0 : pwmgen
  generic
  map(
  CLOCK_FREQ => CLOCK_FREQ,
  HIGH_TIME  => HIGH_TIME,
  LOW_TIME   => LOW_TIME,
  TOTAL_TIME => TOTAL_TIME)
  port map
  (
    clk_i  => clock,
    rst_n  => reset_n,
    d_i    => pwm_data,
    dv_i   => pwm_data_valid,
    en_i   => pwm_en,
    pwm_o  => pwm,
    done_o => pwm_done);

  memreadinterface_i0 : memreadinterface
  generic
  map (
  CLOCK_FREQ     => CLOCK_FREQ,
  RESET_TIME     => RESET_TIME,
  N              => N,
  MEM_DATA_WIDTH => DATA_WIDTH,
  MEM_ADDR_WIDTH => ADDR_WIDTH)
  port
  map (
  clk_i       => clock,
  rst_n       => reset_n,
  mem_a_o     => mem_ra,
  mem_d_i     => mem_rd,
  dv_o        => pwm_data_valid,
  d_o         => pwm_data,
  done_pwm_i  => pwm_done,
  en_pwm_o    => pwm_en,
  idle_o      => idle,
  new_frame_i => new_frame);

  mem_i0 : mem
  port
  map (
  clk_i => clock,
  wd_i  => mem_wd,
  wa_i  => mem_wa,
  we_i  => mem_we,
  rd_o  => mem_rd,
  ra_i  => mem_ra);

  memwriteinterface_i0 : memwriteinterface
  generic
  map (
  N              => N,
  MEM_DATA_WIDTH => DATA_WIDTH,
  MEM_ADDR_WIDTH => ADDR_WIDTH)
  port
  map(
  clk_i       => clock,
  rst_n       => reset_n,
  mem_a_o     => mem_wa,
  mem_d_o     => mem_wd,
  mem_we_o    => mem_we,
  d_i         => spi_data,
  dv_i        => spi_data_valid,
  new_frame_o => new_frame,
  spi_cs_i    => spi_cs_in);

  spi_slave_i0 : spi_slave
  port
  map(
  rst_n      => reset_n,
  spi_cs_i   => spi_cs_in,
  spi_clk_i  => spi_clk_in,
  spi_mosi_i => spi_mosi_in,
  dv_o       => spi_data_valid,
  d_o        => spi_data);

end architecture rtl;