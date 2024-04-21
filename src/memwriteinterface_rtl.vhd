library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memwriteinterface is
  generic
  (
    N              : natural;
    MEM_DATA_WIDTH : natural; -- Width of each data word
    MEM_ADDR_WIDTH : natural); -- Address width
  port
  (
    clk_i       : in  std_ulogic;
    rst_n       : in  std_ulogic;
    mem_a_o     : out std_ulogic_vector(MEM_ADDR_WIDTH - 1 downto 0);
    mem_d_o     : out std_ulogic_vector(MEM_DATA_WIDTH - 1 downto 0);
    mem_we_o    : out std_ulogic;
    dv_i        : in  std_ulogic;
    d_i         : in  std_ulogic_vector(7 downto 0);
    new_frame_o : out std_ulogic;
    spi_cs_i    : in  std_ulogic);
end entity;

architecture rtl of memwriteinterface is

  signal index              : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal inactive           : std_ulogic;

  -- data valid signals for syncing
  signal dv1, sync_spi_cs_1 : std_ulogic;
  signal dv2, sync_spi_cs_2 : std_ulogic;
  signal dv3                : std_ulogic;
  signal s_dv               : std_ulogic;

begin

  -- sync dv
  sync_data_valid : process (clk_i, rst_n)
  begin
    if (rst_n = '0') then
      dv1 <= '0';
      dv2 <= '0';
      dv3 <= '0';
    elsif (rising_edge(clk_i)) then
      dv1 <= dv_i;
      dv2 <= dv1;
      dv3 <= dv2;
    end if;
  end process;

  s_dv        <= not dv3 and dv2; -- rising edge detection

  --  sync_new_message : process (clk_i, rst_n)
  --  begin
  --    if (rst_n = '0') then
  --      sync_spi_cs_1 <= '0';
  --      sync_spi_cs_2 <= '0';
  --      inactive      <= '0';
  --    elsif (rising_edge(clk_i)) then
  --      sync_spi_cs_1 <= spi_cs_i;
  --      sync_spi_cs_2 <= sync_spi_cs_1;
  --      inactive      <= sync_spi_cs_2;
  --    end if;
  --  end process;

  inactive    <= spi_cs_i;

  new_frame_o <= '1' when index >= N - 1
                 and
                 s_dv = '1'
                 else
                 '0';

  mem_d_o <= d_i when s_dv = '1' else
             (others => '0');
  mem_a_o  <= std_ulogic_vector(index);
  mem_we_o <= s_dv;

  index_counter_p : process (clk_i, rst_n)
  begin
    if (rst_n = '0') then
      index <= (others => '0');
    elsif (rising_edge(clk_i)) then
      if (inactive = '1') then
        index <= (others => '0');
      elsif (s_dv = '1') then
        if (index >= N - 1) then
          index <= (others => '0');
        else
          index <= index + 1;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;