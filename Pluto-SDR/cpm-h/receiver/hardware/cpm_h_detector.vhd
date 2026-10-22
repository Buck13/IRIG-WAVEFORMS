library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Correlation front end plus 256-state CPM-H Viterbi/traceback decoder.
entity cpm_h_detector is
  generic(TRACEBACK_DEPTH : positive := 32);
  port(
    clk,reset : in std_logic;
    sample_valid : in std_logic;
    sample_ready : out std_logic;
    symbol_start : in std_logic;
    epoch : in unsigned(1 downto 0);
    rx_i,rx_q : in signed(11 downto 0);
    decoded_valid : out std_logic;
    decoded_dibit : out unsigned(1 downto 0);
    detector_busy : out std_logic;
    overflow : out std_logic
  );
end entity;

architecture rtl of cpm_h_detector is
  signal corr_valid,corr_last,corr_overflow : std_logic;
  signal corr_index : unsigned(5 downto 0);
  signal corr_re,corr_im : signed(17 downto 0);
  signal decoder_ready,decoder_busy,traceback_busy : std_logic;
  signal active_epoch,result_epoch : unsigned(1 downto 0) := (others=>'0');
begin
  correlations: entity work.cpm_correlation_bank
    port map(clk,reset,sample_valid,sample_ready,symbol_start,epoch(0),rx_i,rx_q,
      corr_valid,corr_index,corr_re,corr_im,corr_last,corr_overflow);

  decoder: entity work.cpm_viterbi_decoder
    generic map(TRACEBACK_DEPTH)
    port map(clk,reset,decoder_ready,decoder_busy,corr_valid,corr_index,
      corr_re,corr_im,corr_last,result_epoch,decoded_valid,decoded_dibit,traceback_busy);

  process(clk)
  begin
    if rising_edge(clk) then
      overflow<='0';
      if reset='1' then active_epoch<=(others=>'0'); result_epoch<=(others=>'0');
      else
        if symbol_start='1' and sample_valid='1' then active_epoch<=epoch; end if;
        if corr_valid='1' and corr_index=0 then result_epoch<=active_epoch; end if;
        if corr_last='1' and decoder_ready='0' then overflow<='1'; end if;
        if corr_overflow='1' then overflow<='1'; end if;
      end if;
    end if;
  end process;
  detector_busy <= decoder_busy or traceback_busy;
end architecture;
