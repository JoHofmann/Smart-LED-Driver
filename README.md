# Smart LED Driver

## Introduction

This is an driver for WS28xx RGB LEDs. This is used to run on a FPGA and is written in VHDL. It converts input data from a SPI interface to serial data that drives the LEDs.

Should work with all WS28xx LEDs. Tested with WS2812B and WS2815B. See [Testing](#Testing).

## SPI Interface

TODO

## Serial data output

![Image not found.](doc/images/WS28xx-data-transfer.png)

For more information see datasheet of your part.

## Usage

Synthesis:
```console
$ make build
```

Flash:
```console
$ make flash
```

Simulation:
```console
$ make sim
$ gtkwave sim/smart_led_driver.ghw &
```

Netlist viewer:
```console
$ make show
```

## Simulation

TODO

## Synthesis

Configuration:

LED count = 384 LEDs
Clock freq. = 12 Mhz
Timings for WS2812B LEDs.

Device utilisation:
```
ICESTORM_LC:   271/ 1280    21%
ICESTORM_RAM:    8/   16    50%
SB_IO:          14/  112    12%
SB_GB:           3/    8    37%
ICESTORM_PLL:    0/    1     0%
SB_WARMBOOT:     0/    1     0%
```

Timing analysis:
```
Max frequency for clock 'spi_clk_in$SB_IO_IN_$glb_clk': 122.17 MHz (PASS at 12.00 MHz)
Max frequency for clock      'clock$SB_IO_IN_$glb_clk': 104.85 MHz (PASS at 12.00 MHz)

Max delay <async>                              -> posedge clock$SB_IO_IN_$glb_clk     : 5.69 ns
Max delay <async>                              -> posedge spi_clk_in$SB_IO_IN_$glb_clk: 8.16 ns
Max delay posedge clock$SB_IO_IN_$glb_clk      -> <async>                             : 8.57 ns
Max delay posedge spi_clk_in$SB_IO_IN_$glb_clk -> posedge clock$SB_IO_IN_$glb_clk     : 3.29 ns
```

## Testing

WS2812B - LED Cube

TODO

WS2815B - LED Matrix

TODO

## Useful links

[LED WS28xx overview](https://docs.google.com/spreadsheets/d/1XuypEHJ6EJb4g1ueQG16nt9-8UFYQO5HtJiBW11wCBg)

## License

[Go to license](LICENSE)