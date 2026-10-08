-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pn15_generator is
  port (
    clk, reset, restart, advance : in std_logic;
    seed : in std_logic_vector(14 downto 0);
    symbol_bit : out std_logic
  );
end entity;

architecture rtl of pn15_generator is
  signal state : std_logic_vector(14 downto 0);
begin
  -- b[n+15] = b[n+14] XOR b[n], output LSB before advancing.
  symbol_bit <= state(0);
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' or restart = '1' then
        if unsigned(seed) = 0 then
          state <= (others => '1');
        else
          state <= seed;
        end if;
      elsif advance = '1' then
        state <= (state(14) xor state(0)) & state(14 downto 1);
      end if;
    end if;
  end process;
end architecture;
