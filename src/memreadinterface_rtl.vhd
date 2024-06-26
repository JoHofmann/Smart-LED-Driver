library ieee;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity memreadinterface is
  generic
  (
    CLOCK_FREQ : natural;
    RESET_TIME : natural;
    N          : natural;
    DATA_WIDTH : natural; -- Width of each data word
    ADDR_WIDTH : natural); -- Address width
  port
  (
    clk_i       : in  std_ulogic;
    rst_n       : in  std_ulogic;
    mem_a_o     : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    mem_d_i     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    done_pwm_i  : in  std_ulogic;
    dv_o        : out std_ulogic;
    d_o         : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    en_pwm_o    : out std_ulogic;
    idle_o      : out std_ulogic;
    new_frame_i : in  std_ulogic);
end entity memreadinterface;

architecture rtl of memreadinterface is

  -- constants
  constant t_reset : natural := CLOCK_FREQ/1_000_000 * RESET_TIME/1000 - 1;

  -- type declaration
  type state_t is (IDLE, FETCH, DELIVER, STREAM, RESET);

  -- signal state machine
  signal cstate, nstate     : state_t;

  -- index counter
  signal index              : unsigned(ADDR_WIDTH - 1 downto 0);

  -- reset timer
  signal reset_counter      : unsigned(natural(ceil(log2(real(t_reset)))) - 1 downto 0);
  signal en_reset_counter   : std_ulogic;
  signal done_reset_counter : std_ulogic;

begin

  mem_a_o <= std_ulogic_vector(index);
  d_o     <= mem_d_i;

  -- index counter  
  index_counter_p : process (clk_i, rst_n)
  begin
    if (rst_n = '0') then
      index <= (others => '0');

    elsif (rising_edge(clk_i) and done_pwm_i = '1') then
      if (index = N - 1) then
        index <= (others => '0');
      else
        index <= index + 1;
      end if;
    end if;
  end process;

  -- reset counter
  reset_counter_p : process (clk_i, rst_n)
  begin
    if (rst_n = '0') then
      reset_counter <= (others => '0');

    elsif rising_edge(clk_i) then

      if en_reset_counter = '1' then
        reset_counter <= reset_counter + 1;
      end if;

      if reset_counter = t_reset then
        reset_counter      <= (others => '0');
        done_reset_counter <= '1';
      else
        done_reset_counter <= '0';
      end if;
    end if;
  end process;

  -- state machine
  cstate <= IDLE when rst_n = '0' else
            nstate when rising_edge(clk_i);

  fsm_transition_p : process (clk_i, cstate, new_frame_i, done_pwm_i)
  begin

    nstate <= cstate;

    case cstate is
      when IDLE =>
        if new_frame_i = '1' then
          nstate <= FETCH;
        end if;

      when FETCH =>
        nstate <= DELIVER;

      when DELIVER =>
        nstate <= STREAM;

      when STREAM =>
        if done_pwm_i = '1' then
          if index = N - 1 then
            nstate <= RESET;
          else
            nstate <= FETCH;
          end if;
        end if;

      when RESET =>
        if done_reset_counter = '1' then

          if new_frame_i = '1' then
            nstate <= FETCH;
          else
            nstate <= IDLE;
          end if;
        end if;

      when others => null;
    end case;
  end process;

  fsm_output_p : process (clk_i)
  begin
    if (rising_edge(clk_i)) then
      case cstate is
        when IDLE =>
          en_pwm_o         <= '0';
          en_reset_counter <= '0';
          dv_o             <= '0';
          idle_o           <= '1';

        when FETCH =>
          en_pwm_o         <= '0';
          en_reset_counter <= '0';
          dv_o             <= '0';
          idle_o           <= '0';

        when DELIVER =>
          en_pwm_o         <= '0';
          en_reset_counter <= '0';
          dv_o             <= '1';
          idle_o           <= '0';

        when STREAM =>
          en_pwm_o         <= '1';
          en_reset_counter <= '0';
          dv_o             <= '0';
          idle_o           <= '0';

        when RESET =>
          en_pwm_o         <= '0';
          en_reset_counter <= '1';
          dv_o             <= '0';
          idle_o           <= '0';
        when others => null;
      end case;
    end if;
  end process;

end architecture rtl;