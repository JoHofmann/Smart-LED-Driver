LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY pwmgen IS
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
END ENTITY;

ARCHITECTURE rtl OF pwmgen IS

-- timings	(timing for reset time in memreadinterface)
CONSTANT t_low : NATURAL := CLOCK_FREQ/1_000_000 * LOW_TIME/1000 - 1;
CONSTANT t_high : NATURAL := CLOCK_FREQ/1_000_000 * HIGH_TIME/1000 - 1;
CONSTANT t_total : NATURAL := CLOCK_FREQ/1_000_000 * TOTAL_TIME/1000 - 1;

-- type declaration
TYPE state_t IS (IDLE, OUTPUT, BIT_COMPLETED, REQUEST, RESET);

-- signal state machine
SIGNAL cstate, nstate : state_t;

-- data buffer
SIGNAL data : STD_ULOGIC_VECTOR(7 DOWNTO 0);

SIGNAL sel_bit : STD_ULOGIC;

-- counter
SIGNAL index : unsigned(2 DOWNTO 0);
SIGNAL timer : unsigned(6 DOWNTO 0);

-- control singals
SIGNAL en_tcnt, en_icnt, t : STD_ULOGIC;

SIGNAL timer_done, done_bit : STD_ULOGIC;

BEGIN

-- select bit
sel_bit <= data(to_integer(index));

pwm_o <= '0' WHEN en_i = '0' ELSE
         '1' WHEN (sel_bit = '1' AND timer <= t_high) OR
         (sel_bit = '0' AND timer <= t_low) ELSE
         '0';

-- load data if valid
load_data_p : PROCESS (clk_i)
BEGIN
IF (rising_edge(clk_i) AND dv_i = '1') THEN
data <= d_i;
END IF;
END PROCESS;

-- Index counter: mod 8 counter with en singal
index_counter_p : PROCESS (clk_i, rst_n)
BEGIN
IF (rst_n = '0') THEN
index <= (OTHERS => '0');

ELSIF (rising_edge(clk_i) AND en_icnt = '1') THEN
IF (index = 7) THEN
index <= (OTHERS => '0');
ELSE
index <= index + 1;
END IF;
END IF;
END PROCESS;

-- Timer counter
timer_counter_p : PROCESS (clk_i, rst_n)
BEGIN
IF (rst_n = '0') THEN
timer <= (OTHERS => '0');
timer_done <= '0';

ELSIF (rising_edge(clk_i) AND en_tcnt = '1') THEN
IF (timer = t_total) THEN
timer <= (OTHERS => '0');
timer_done <= '1';
ELSE
timer <= timer + 1;
timer_done <= '0';
END IF;
END IF;
END PROCESS;

-- done signal
done_o <= '1' WHEN (timer = t_total - 2 AND index = 7) ELSE
          '0';
done_bit <= '1' WHEN timer = t_total - 1 ELSE
            '0';

-- state machine
cstate <= IDLE WHEN rst_n = '0' ELSE
          nstate WHEN rising_edge(clk_i);

fsm_transition_p : PROCESS (clk_i, rst_n, dv_i, done_bit)
BEGIN
nstate <= cstate;
CASE cstate IS
WHEN IDLE =>
IF dv_i = '1' THEN
nstate <= OUTPUT;
END IF;
WHEN OUTPUT =>
IF (done_bit = '1') THEN
nstate <= BIT_COMPLETED;
END IF;
WHEN BIT_COMPLETED =>
IF (index = 7) THEN
IF (dv_i = '1') THEN
nstate <= OUTPUT;
ELSE
nstate <= IDLE;
END IF;
ELSE
nstate <= OUTPUT;
END IF;
WHEN OTHERS => NULL;
END CASE;
END PROCESS;

fsm_output_p : PROCESS (clk_i)
BEGIN
IF (rising_edge(clk_i)) THEN
CASE cstate IS
WHEN IDLE =>
en_icnt <= '0';
en_tcnt <= '0';
WHEN OUTPUT =>
en_icnt <= '0';
en_tcnt <= '1';
WHEN BIT_COMPLETED =>
en_icnt <= '1';
en_tcnt <= '1';
WHEN OTHERS => NULL;
END CASE;
END IF;
END PROCESS;
END ARCHITECTURE rtl;