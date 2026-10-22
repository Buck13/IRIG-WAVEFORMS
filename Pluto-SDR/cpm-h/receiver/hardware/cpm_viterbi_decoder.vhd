library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_viterbi_decoder is
  generic(TRACEBACK_DEPTH : positive := 32);
  port(
    clk, reset : in std_logic;
    ready, busy : out std_logic;
    correlation_write_valid : in std_logic;
    correlation_write_index : in unsigned(5 downto 0);
    correlation_write_re, correlation_write_im : in signed(17 downto 0);
    start : in std_logic;
    epoch : in unsigned(1 downto 0);
    decoded_valid : out std_logic;
    decoded_dibit : out unsigned(1 downto 0);
    traceback_busy : out std_logic
  );
end entity;

architecture rtl of cpm_viterbi_decoder is
  signal epoch_q : unsigned(1 downto 0) := (others => '0');
  signal engine_done, survivor_valid : std_logic;
  signal destination0, destination1 : unsigned(7 downto 0);
  signal survivor0, survivor1 : unsigned(1 downto 0);
  signal metric0, metric1 : signed(47 downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then epoch_q<=(others=>'0');
      elsif start='1' then epoch_q<=epoch;end if;
    end if;
  end process;

  engine : entity work.cpm_viterbi_engine
    port map(clk,reset,ready,busy,correlation_write_valid,correlation_write_index,
      correlation_write_re,correlation_write_im,start,epoch_q,
      survivor_valid,destination0,destination1,survivor0,survivor1,
      metric0,metric1,engine_done);

  traceback : entity work.cpm_survivor_traceback
    generic map(TRACEBACK_DEPTH)
    port map(clk,reset,survivor_valid,destination0,destination1,survivor0,survivor1,
      metric0,metric1,engine_done,epoch_q,decoded_valid,decoded_dibit,traceback_busy);
end architecture;
