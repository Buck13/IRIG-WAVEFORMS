-- Streaming squared-IQ branch metric for one CPM candidate waveform.
-- One aligned received/template sample is accepted per valid clock.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_branch_metric is
  generic (
    IQ_BITS : positive := 12;
    METRIC_BITS : positive := 32
  );
  port (
    clk, reset : in std_logic;
    sample_valid : in std_logic;
    symbol_start, symbol_last : in std_logic;
    rx_i, rx_q, template_i, template_q : in signed(IQ_BITS-1 downto 0);
    metric_valid : out std_logic;
    metric : out unsigned(METRIC_BITS-1 downto 0)
  );
end entity;

architecture rtl of cpm_branch_metric is
  signal accumulator : unsigned(METRIC_BITS-1 downto 0) := (others => '0');
begin
  process(clk)
    variable di, dq : signed(IQ_BITS downto 0);
    variable di2, dq2 : unsigned(2*IQ_BITS+1 downto 0);
    variable term : unsigned(METRIC_BITS-1 downto 0);
    variable total : unsigned(METRIC_BITS-1 downto 0);
  begin
    if rising_edge(clk) then
      metric_valid <= '0';
      if reset = '1' then
        accumulator <= (others => '0');
        metric <= (others => '0');
      elsif sample_valid = '1' then
        di := resize(rx_i, di'length) - resize(template_i, di'length);
        dq := resize(rx_q, dq'length) - resize(template_q, dq'length);
        di2 := unsigned(di * di);
        dq2 := unsigned(dq * dq);
        term := resize(di2, METRIC_BITS) + resize(dq2, METRIC_BITS);
        if symbol_start = '1' then total := term;
        else total := accumulator + term;
        end if;
        accumulator <= total;
        if symbol_last = '1' then
          metric <= total;
          metric_valid <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
