library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_metric_tdp_ram is
  port(
    clk : in std_logic;
    we_a : in std_logic;
    addr_a : in unsigned(5 downto 0);
    din_a : in signed(47 downto 0);
    dout_a : out signed(47 downto 0);
    addr_b : in unsigned(5 downto 0);
    dout_b : out signed(47 downto 0)
  );
end entity;

architecture rtl of cpm_metric_tdp_ram is
  type ram_t is array(0 to 63) of signed(47 downto 0);
  signal ram : ram_t;
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we_a = '1' then
        ram(to_integer(addr_a)) <= din_a;
      end if;
      dout_a <= ram(to_integer(addr_a));
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      dout_b <= ram(to_integer(addr_b));
    end if;
  end process;
end architecture;
