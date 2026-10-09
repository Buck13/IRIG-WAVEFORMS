-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;
use ieee.std_logic_1164.all;

entity pn15_bpsk_tx is
  generic (SAMPLES_PER_SYMBOL : positive := 8);
  port (
    clk, reset, enable, restart : in std_logic;
    seed : in std_logic_vector(14 downto 0);
    m_axis_tdata : out std_logic_vector(31 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in std_logic
  );
end entity;

architecture rtl of pn15_bpsk_tx is
  signal valid, advance, symbol_bit : std_logic;
  signal sample_index : natural range 0 to SAMPLES_PER_SYMBOL - 1;
begin
  m_axis_tvalid <= valid;
  advance <= '1' when valid = '1' and m_axis_tready = '1' and
                          sample_index = SAMPLES_PER_SYMBOL - 1 else '0';
  pn : entity work.pn15_generator
    port map (clk => clk, reset => reset, restart => restart,
              advance => advance, seed => seed, symbol_bit => symbol_bit);
  mapper : entity work.bpsk_mapper
    port map (symbol_bit => symbol_bit, iq => m_axis_tdata);

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' or restart = '1' then
        valid <= '0';
        sample_index <= 0;
      elsif valid = '0' or m_axis_tready = '1' then
        valid <= enable;
        if valid = '1' and m_axis_tready = '1' then
          if sample_index = SAMPLES_PER_SYMBOL - 1 then
            sample_index <= 0;
          else
            sample_index <= sample_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
