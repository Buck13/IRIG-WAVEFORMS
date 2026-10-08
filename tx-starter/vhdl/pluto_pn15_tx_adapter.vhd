-- SPDX-License-Identifier: GPL-3.0-or-later
-- All controls must be synchronous to clk. Supply CDC outside this module.
-- Like util_upack2, a request captures the next sample AFTER the rising edge.
library ieee;
use ieee.std_logic_1164.all;

entity pluto_pn15_tx_adapter is
  generic (SAMPLES_PER_SYMBOL : positive := 8);
  port (
    clk, reset, select_pn, enable, restart : in std_logic;
    seed : in std_logic_vector(14 downto 0);
    sample_request : in std_logic;
    dma_i, dma_q : in std_logic_vector(15 downto 0);
    tx_i, tx_q : out std_logic_vector(15 downto 0);
    sample_valid : out std_logic
  );
end entity;

architecture rtl of pluto_pn15_tx_adapter is
  signal core_reset, core_enable, core_ready, core_valid : std_logic;
  signal core_data, sample_data : std_logic_vector(31 downto 0);
begin
  core_reset <= reset or not select_pn;
  core_enable <= enable and select_pn;
  core_ready <= sample_request and enable and select_pn and not restart;
  core : entity work.pn15_bpsk_tx
    generic map (SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL)
    port map (clk => clk, reset => core_reset, enable => core_enable,
      restart => restart, seed => seed, m_axis_tdata => core_data,
      m_axis_tvalid => core_valid, m_axis_tready => core_ready);

  -- Bypass adds no pipeline stage to the original DMA data path.
  tx_i <= dma_i when select_pn = '0' else sample_data(31 downto 16);
  tx_q <= dma_q when select_pn = '0' else sample_data(15 downto 0);
  process(clk)
  begin
    if rising_edge(clk) then
      sample_valid <= '0';
      if core_reset = '1' or restart = '1' or enable = '0' then
        sample_data <= (others => '0');
      elsif sample_request = '1' then
        if core_valid = '1' then
          sample_data <= core_data;
          sample_valid <= '1';
        else
          sample_data <= (others => '0');
        end if;
      end if;
    end if;
  end process;
end architecture;
