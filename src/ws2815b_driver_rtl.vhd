LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY ws2815b_driver IS
PORT (
CLOCK_50 : IN STD_ULOGIC;
RESET_N : IN STDULOGIC;
SPI_CLK_IN : IN STDULOGIC;
SPI_MOSI_IN : IN STD_ULOGIC;
SPI_CS_IN : IN STD_ULOGIC;
INTERRUPT_OUT : OUT STD_ULOGIC;
SERIAL_OUT : OUT STD_ULOGIC;
LA_0 : OUT STD_ULOGIC;
LA_1 : OUT STD_ULOGIC;
LA_2 : OUT STD_ULOGIC;
LA_3 : OUT STD_ULOGIC;
LA_4 : OUT STD_ULOGIC;
LA_5 : OUT STD_ULOGIC;
LA_6 : OUT STD_ULOGIC);
END ENTITY;

ARCHITECTURE rtl OF ws2815b_driver IS

-- configuration
CONSTANT CLOCK_FREQ : NATURAL := 12_000_000; -- system clock
CONSTANT LOW_TIME : NATURAL := 350; -- ns
CONSTANT HIGH_TIME : NATURAL := 700; -- ns
CONSTANT TOTAL_TIME : NATURAL := 1_250; -- ns
CONSTANT RESET_TIME : NATURAL := 280_000; -- ns
CONSTANT N : NATURAL := 3 * 3; --> N = number of bytes => N = LED_count*3

-- spi_slave x memwriteinterface
SIGNAL spi_data_valid : STD_ULOGIC;
SIGNAL spi_data : STD_ULOGIC_VECTOR(7 DOWNTO 0);

-- memwriteinterface x memreadinterface
SIGNAL new_frame : STD_ULOGIC;

-- memreadinterface x pwmgen
SIGNAL pwm_data : STD_ULOGIC_VECTOR(7 DOWNTO 0);
SIGNAL pwm_data_valid : STD_ULOGIC;
SIGNAL pwm_done, pwm_en : STD_ULOGIC;

-- pwmgen
SIGNAL pwm : STD_ULOGIC;

-- memory
SIGNAL mem_wd, mem_rd : STD_ULOGIC_VECTOR(7 DOWNTO 0);
SIGNAL mem_wa, mem_ra : STD_ULOGIC_VECTOR(12 DOWNTO 0);
SIGNAL mem_we : STD_ULOGIC;

-- status
SIGNAL idle : STD_ULOGIC;

COMPONENT pwmgen
GENERIC (
CLOCK_FREQ : NATURAL;
HIGH_TIME : NATURAL;
LOW_TIME : NATURAL;
TOTAL_TIME : NATURAL);
PORT (
clk_i : IN STD_ULOGIC;
rst_n : IN STD_ULOGIC;
d_i : IN STD_ULOGIC_VECTOR(7 DOWNTO 0);
dv_i : IN STD_ULOGIC;
en_i : IN STD_ULOGIC;
pwm_o : OUT STD_ULOGIC;
done_o : OUT STD_ULOGIC);
END COMPONENT;

COMPONENT memreadinterface
GENERIC (
CLOCK_FREQ : NATURAL;
RESET_TIME : NATURAL;
N : NATURAL);
PORT (
clk_i : IN STD_ULOGIC;
rst_n : IN STD_ULOGIC;
mem_a_o : OUT STD_ULOGIC_VECTOR(12 DOWNTO 0);
mem_d_i : IN STD_ULOGIC_VECTOR(7 DOWNTO 0);
done_pwm_i : IN STD_ULOGIC;
dv_o : OUT STD_ULOGIC;
d_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0);
en_pwm_o : OUT STD_ULOGIC;
idle_o : OUT STD_ULOGIC;
new_frame_i : IN STD_ULOGIC);
END COMPONENT;

COMPONENT mem
PORT (
clk_i : IN STD_ULOGIC;
wd_i : IN STD_ULOGIC_VECTOR(7 DOWNTO 0); -- Write Data
wa_i : IN STD_ULOGIC_VECTOR(12 DOWNTO 0); -- Write Address
we_i : IN STD_ULOGIC; -- Write Enable
rd_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- Read Data
ra_i : IN STD_ULOGIC_VECTOR(12 DOWNTO 0)); -- Read Address 
END COMPONENT;

COMPONENT memwriteinterface
GENERIC (
N : NATURAL);
PORT (
clk_i : IN STD_ULOGIC;
rst_n : IN STD_ULOGIC;
mem_a_o : OUT STD_ULOGIC_VECTOR(12 DOWNTO 0);
mem_d_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0);
mem_we_o : OUT STD_ULOGIC;
dv_i : IN STD_ULOGIC;
d_i : IN STD_ULOGIC_VECTOR(7 DOWNTO 0);
new_frame_o : OUT STD_ULOGIC);

END COMPONENT;

COMPONENT spi_slave IS
PORT (
rst_n : IN STD_ULOGIC;
spi_cs_i : IN STD_ULOGIC;
spi_clk_i : IN STD_ULOGIC;
spi_mosi_i : IN STD_ULOGIC;
dv_o : OUT STD_ULOGIC;
d_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0));
END COMPONENT;

BEGIN

LA_0 <= CLOCK_50;
LA_1 <= RESET_N;
LA_2 <= pwm;
LA_3 <= SPI_CLK_IN;
LA_4 <= pwm;
LA_5 <= SPI_CS_IN;
LA_6 <= idle;
-- signal mapping	
SERIAL_OUT <= pwm;
INTERRUPT_OUT <= idle;

pwmgen_i0 : pwmgen
GENERIC MAP(
CLOCK_FREQ => CLOCK_FREQ,
HIGH_TIME => HIGH_TIME,
LOW_TIME => LOW_TIME,
TOTAL_TIME => TOTAL_TIME)
PORT MAP
(
clk_i => CLOCK_50,
rst_n => RESET_N,
d_i => pwm_data,
dv_i => pwm_data_valid,
en_i => pwm_en,
pwm_o => pwm,
done_o => pwm_done);

memreadinterface_i0 : memreadinterface
GENERIC MAP(
CLOCK_FREQ => CLOCK_FREQ,
RESET_TIME => RESET_TIME,
N => N)
PORT MAP(
clk_i => CLOCK_50,
rst_n => RESET_N,
mem_a_o => mem_ra,
mem_d_i => mem_rd,
dv_o => pwm_data_valid,
d_o => pwm_data,
done_pwm_i => pwm_done,
en_pwm_o => pwm_en,
idle_o => idle,
new_frame_i => new_frame);

mem_i0 : mem
PORT MAP(
clk_i => CLOCK_50,
wd_i => mem_wd,
wa_i => mem_wa,
we_i => mem_we,
rd_o => mem_rd,
ra_i => mem_ra);

memwriteinterface_i0 : memwriteinterface
GENERIC MAP(
N => N)
PORT MAP(
clk_i => CLOCK_50,
rst_n => RESET_N,
mem_a_o => mem_wa,
mem_d_o => mem_wd,
mem_we_o => mem_we,
d_i => spi_data,
dv_i => spi_data_valid,
new_frame_o => new_frame);

spi_slave_i0 : spi_slave
PORT MAP(
rst_n => RESET_N,
spi_cs_i => SPI_CS_IN,
spi_clk_i => SPI_CLK_IN,
spi_mosi_i => SPI_MOSI_IN,
dv_o => spi_data_valid,
d_o => spi_data);

END ARCHITECTURE rtl;