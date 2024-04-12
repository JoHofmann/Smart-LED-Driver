library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ws2815b_driver is 
	port (   
		CLOCK_50     	: in  std_ulogic;
		RESET_N		 	: in  std_ulogic;
	  	SPI_CLK_IN	 	: in  std_ulogic;
	  	SPI_MOSI_IN	 	: in  std_ulogic;
	  	SPI_CS_IN 	 	: in  std_ulogic;
		INTERRUPT_OUT 	: out std_ulogic;
	  	SERIAL_OUT   	: out std_ulogic;
		LA_0    : out std_ulogic;
		LA_1    : out std_ulogic;
		LA_2    : out std_ulogic;
		LA_3    : out std_ulogic;
		LA_4    : out std_ulogic;
		LA_5    : out std_ulogic;
		LA_6    : out std_ulogic);
end entity;

architecture rtl of ws2815b_driver is
	
    -- configuration
    constant CLOCK_FREQ : natural := 12_000_000;    -- system clock
	constant LOW_TIME   : natural := 300;	 -- ns
	constant HIGH_TIME  : natural := 1_000;	 -- ns
	constant TOTAL_TIME : natural := 12_500; -- ns
	constant RESET_TIME : natural := 280_000; -- ns
	constant N : integer := 24*3;		--> N = number of bytes => N = LED_count*3

	-- spi_slave x memwriteinterface
	signal spi_data_valid : std_ulogic;
	signal spi_data : std_ulogic_vector(7 downto 0);

	-- memwriteinterface x memreadinterface
	signal new_frame : std_ulogic;

	-- memreadinterface x pwmgen
	signal pwm_data       : std_ulogic_vector(7 downto 0);
	signal pwm_data_valid : std_ulogic;
	signal pwm_done, pwm_en : std_ulogic;

	-- pwmgen
	signal pwm : std_ulogic;

	-- memory
	signal mem_wd, mem_rd : std_ulogic_vector(7 downto 0);
	signal mem_wa, mem_ra : std_ulogic_vector(12 downto 0);
	signal mem_we         : std_ulogic;

	-- status
	signal idle : std_ulogic;

	component pwmgen
	generic(
		CLOCK_FREQ	: natural;
		HIGH_TIME	: natural;
		LOW_TIME	: natural;
		TOTAL_TIME	: natural);
  	port ( 
		clk_i    : in  std_ulogic;
		rst_n    : in  std_ulogic;
		d_i      : in  std_ulogic_vector(7 downto 0);
		dv_i     : in  std_ulogic;
		en_i	 : in  std_ulogic;
		pwm_o    : out std_ulogic;
		done_o   : out std_ulogic);
  	end component;
  
	component memreadinterface
 	generic(
		CLOCK_FREQ : natural;
		RESET_TIME : natural;
    	N : integer);
  	port ( 
		clk_i      	: in  std_ulogic;
		rst_n      	: in  std_ulogic;
		mem_a_o    	: out std_ulogic_vector(12 downto 0);
		mem_d_i    	: in  std_ulogic_vector(7 downto 0);
		done_pwm_i 	: in  std_ulogic;
		dv_o       	: out std_ulogic;
		d_o        	: out std_ulogic_vector(7 downto 0);
		en_pwm_o   	: out std_ulogic;
		idle_o 	   	: out std_ulogic;
		new_frame_i : in  std_ulogic);
  	end component;
  
	component mem
    port ( 
		clk_i   : in  std_ulogic;
		wd_i    : in  std_ulogic_vector(7 downto 0);    -- Write Data
		wa_i    : in  std_ulogic_vector(12 downto 0);   -- Write Address
		we_i    : in  std_ulogic;                       -- Write Enable
		rd_o    : out std_ulogic_vector(7 downto 0);    -- Read Data
		ra_i    : in  std_ulogic_vector(12 downto 0));  -- Read Address 
  	end component;
 
	component memwriteinterface
	generic(
		N : integer);
	port ( 
		clk_i      : in  std_ulogic;
		rst_n      : in  std_ulogic;
		mem_a_o    : out std_ulogic_vector(12 downto 0);
		mem_d_o    : out std_ulogic_vector(7 downto 0);
		mem_we_o   : out std_ulogic;
		dv_i       : in  std_ulogic;
		d_i        : in  std_ulogic_vector(7 downto 0);
		new_frame_o : out std_ulogic);
	
	end component;

	component spi_slave is
	port ( 
		rst_n      : in  std_ulogic;
		spi_cs_i   : in  std_ulogic;
		spi_clk_i  : in  std_ulogic;
		spi_mosi_i : in  std_ulogic;
		dv_o       : out std_ulogic;
		d_o        : out std_ulogic_vector(7 downto 0));
	end component;

begin

	LA_0 <= CLOCK_50;
	LA_1 <= RESET_N;
	LA_2 <= pwm;
	LA_3 <= SPI_CLK_IN;
	LA_4 <= pwm;
	LA_5 <= SPI_CS_IN;
	LA_6 <= idle;


	-- signal mapping	
	SERIAL_OUT 	 	<= pwm;
	INTERRUPT_OUT 	<= idle;
	
	pwmgen_i0 : pwmgen
	generic map(
		CLOCK_FREQ	=> CLOCK_FREQ,
		HIGH_TIME	=> HIGH_TIME,
		LOW_TIME	=> LOW_TIME,
		TOTAL_TIME	=> TOTAL_TIME)
	port map (
		clk_i 		=> CLOCK_50,
		rst_n 		=> RESET_N,
		d_i   		=> pwm_data,
		dv_i  		=> pwm_data_valid,
		en_i	  	=> pwm_en,
		pwm_o  		=> pwm,
		done_o 		=> pwm_done);
	
	memreadinterface_i0 : memreadinterface
	generic map ( 
		CLOCK_FREQ => CLOCK_FREQ,
		RESET_TIME => RESET_TIME,
		N => N)
	port map (
		clk_i      	=> CLOCK_50,
		rst_n      	=> RESET_N,
		mem_a_o     => mem_ra,
		mem_d_i     => mem_rd,
		dv_o      	=> pwm_data_valid,
		d_o     	=> pwm_data,
		done_pwm_i 	=> pwm_done,
		en_pwm_o 	=> pwm_en,
		idle_o 		=> idle,
		new_frame_i	=> new_frame);

	mem_i0 : mem
    port map (
		clk_i  	=> CLOCK_50,
		wd_i   	=> mem_wd,
		wa_i   	=> mem_wa,
		we_i   	=> mem_we,
		rd_o   	=> mem_rd,
		ra_i   	=> mem_ra);
   
	memwriteinterface_i0 : memwriteinterface
	generic map ( 
	  	N => N)
	port map( 
	  	clk_i      => CLOCK_50,
	  	rst_n      => RESET_N,
	  	mem_a_o    => mem_wa,
	  	mem_d_o    => mem_wd,
	  	mem_we_o   => mem_we,
	  	d_i        => spi_data,
	  	dv_i       => spi_data_valid,
	  	new_frame_o => new_frame);

	spi_slave_i0 : spi_slave
	port map( 
	  	rst_n      => RESET_N,
	  	spi_cs_i   => SPI_CS_IN,
	  	spi_clk_i  => SPI_CLK_IN,
	  	spi_mosi_i => SPI_MOSI_IN,
	  	dv_o       => spi_data_valid,
	  	d_o        => spi_data);

end architecture rtl;