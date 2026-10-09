-- SPDX-License-Identifier: GPL-3.0-or-later
-- Channel 0 source selector. The sole ARM control bit is synchronised here.
library ieee;
use ieee.std_logic_1164.all;
entity pluto_pn15_tx_top is
  generic (SAMPLES_PER_SYMBOL : positive := 8);
  port (
    clk, reset : in std_logic;
    select_async : in std_logic_vector(0 downto 0);
    enable_i, enable_q, sample_request : in std_logic;
    dma_i, dma_q : in std_logic_vector(15 downto 0);
    tx_i, tx_q : out std_logic_vector(15 downto 0)
  );
end entity;
architecture rtl of pluto_pn15_tx_top is
  signal select_meta, select_sync : std_logic := '0';
  signal enable_pair : std_logic;
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of select_meta, select_sync : signal is "TRUE";
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of select_meta, select_sync : signal is "NO";
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        select_meta <= '0';
        select_sync <= '0';
      else
        select_meta <= select_async(0);
        select_sync <= select_meta;
      end if;
    end if;
  end process;
  enable_pair <= enable_i and enable_q;
  source : entity work.pluto_pn15_tx_adapter
    generic map (SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL)
    port map (clk => clk, reset => reset, select_pn => select_sync,
      enable => enable_pair, restart => '0', seed => "111111111111111",
      sample_request => sample_request, dma_i => dma_i, dma_q => dma_q,
      tx_i => tx_i, tx_q => tx_q, sample_valid => open);
end architecture;
