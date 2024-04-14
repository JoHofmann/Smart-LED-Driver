library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity smart_led_driver_tb is
end entity;

architecture tbench of smart_led_driver_tb is

  component smart_led_driver is
    port
    (
      clock_50      : in  std_ulogic;
      reset_n       : in  std_ulogic;
      spi_clk_in    : in  std_ulogic;
      spi_mosi_in   : in  std_ulogic;
      spi_cs_in     : in  std_ulogic;
      interrupt_out : out std_ulogic;
      serial_out    : out std_ulogic);
  end component;

  -- constants
  constant LED_COUNT               : natural := 100;
  constant N                       : natural := LED_COUNT * 3; --> N = number of bytes e.g. N = LED_count*3

  -- simulation signals
  signal clock_50, reset           : std_ulogic;

  -- spi signals
  signal spi_clk, spi_cs, spi_mosi : std_ulogic;

  -- output, interrupt
  signal serial_out, interrupt     : std_ulogic;

  procedure RunCycle(signal clk_50 : out std_ulogic) is
  begin
    clk_50 <= '0';
    wait for 10 ns;
    clk_50 <= '1';
    wait for 10 ns;
  end procedure;

  procedure SPIRunCycle(signal clk : out std_ulogic) is
  begin
    clk <= '0';
    wait for 20 ns;
    clk <= '1';
    wait for 20 ns;
  end procedure;

  procedure GenerateDummySPI(signal clk, cs, mosi : out std_ulogic) is
  begin
    cs   <= '1';
    clk  <= '0';
    mosi <= '0';
    wait for 100 ns;

    cs <= '0';
    wait for 5 ns;

    for k in 0 to N * 8 - 1 loop
      if k mod 2 = 0 then
        mosi <= '1';
      else
        mosi <= '0';
      end if;
      SPIRunCycle(clk);
    end loop;

    wait for 5 ns;
    cs  <= '1';
    clk <= '0';
  end procedure;

begin

  smart_led_driver_i0 : smart_led_driver
  port map
  (
    clock_50      => clock_50,
    reset_n       => reset,
    spi_clk_in    => spi_clk,
    spi_mosi_in   => spi_mosi,
    spi_cs_in     => spi_cs,
    interrupt_out => interrupt,
    serial_out    => serial_out);

  -- simulate single spi transmission
  spi_gen_p : process
  begin
    GenerateDummySPI(spi_clk, spi_cs, spi_mosi);
    wait;
  end process;

  -- simulate clock, reset
  reset <= '1', '0' after 20 ns, '1' after 40 ns;

  clk_p : process
  begin
    RunCycle(clock_50);
  end process clk_p;

end; -- architecture