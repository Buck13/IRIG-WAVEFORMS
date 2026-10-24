library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_rx_manual_frontend is
  generic(TRACEBACK_DEPTH:positive:=32);
  port(
    clk,reset,enable,restart:in std_logic;
    timing_offset:in unsigned(4 downto 0);
    start_epoch:in unsigned(1 downto 0);
    adc_valid_i,adc_valid_q:in std_logic;
    adc_i,adc_q:in std_logic_vector(15 downto 0);
    decoded_valid:out std_logic;
    decoded_dibit:out unsigned(1 downto 0);
    aligned,detector_busy,dropped_observation,overflow:out std_logic
  );
end entity;

architecture rtl of cpm_rx_manual_frontend is
  signal sample_valid,sample_ready,symbol_start:std_logic;
  signal sample_i,sample_q:signed(11 downto 0);
  signal epoch:unsigned(1 downto 0);
  signal adapter_drop,detector_overflow:std_logic;
  signal receiver_reset:std_logic;
begin
  receiver_reset<=reset or restart or not enable;
  adapter:entity work.cpm_rx_observation_adapter
    port map(clk,reset,enable,restart,timing_offset,start_epoch,
      adc_valid_i,adc_valid_q,adc_i,adc_q,sample_ready,
      sample_valid,symbol_start,sample_i,sample_q,epoch,aligned,adapter_drop);
  detector:entity work.cpm_h_detector
    generic map(TRACEBACK_DEPTH)
    port map(clk,receiver_reset,sample_valid,sample_ready,symbol_start,epoch,sample_i,sample_q,
      decoded_valid,decoded_dibit,detector_busy,detector_overflow);
  dropped_observation<=adapter_drop;
  overflow<=detector_overflow;
end architecture;
