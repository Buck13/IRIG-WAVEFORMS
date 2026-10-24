library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Processor-controlled wrapper used by the first manual-acquisition Pluto image.
entity pluto_cpm_rx_controlled is
  port(
    clk,reset:in std_logic;
    control:in std_logic_vector(8 downto 0);
    adc_valid:in std_logic;
    adc_iq:in std_logic_vector(31 downto 0);
    status:out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of pluto_cpm_rx_controlled is
  signal decoded_valid,aligned,busy,dropped,overflow:std_logic;
  signal decoded_dibit:unsigned(1 downto 0);
  signal drop_sticky,overflow_sticky:std_logic:='0';
  signal decoded_count:unsigned(15 downto 0):=(others=>'0');
  signal latest:unsigned(1 downto 0):=(others=>'0');
  signal quality_done:std_logic;
  signal quality_errors,quality_checked:unsigned(6 downto 0);
  signal receiver_reset:std_logic;
begin
  receiver_reset<=reset or control(1) or not control(0);
  receiver:entity work.cpm_rx_manual_frontend
    port map(clk,reset,control(0),control(1),unsigned(control(6 downto 2)),
      unsigned(control(8 downto 7)),adc_valid,adc_valid,
      adc_iq(15 downto 0),adc_iq(31 downto 16),
      decoded_valid,decoded_dibit,aligned,busy,dropped,overflow);

  quality:entity work.cpm_pn15_quality
    port map(clk,receiver_reset,decoded_valid,decoded_dibit,
      quality_done,quality_errors,quality_checked);

  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' or control(1)='1' or control(0)='0' then
        drop_sticky<='0';overflow_sticky<='0';decoded_count<=(others=>'0');latest<=(others=>'0');
      else
        if dropped='1' then drop_sticky<='1';end if;
        if overflow='1' then overflow_sticky<='1';end if;
        if decoded_valid='1' then decoded_count<=decoded_count+1;latest<=decoded_dibit;end if;
      end if;
    end if;
  end process;

  status<=quality_done & std_logic_vector(quality_errors) &
    std_logic_vector(quality_checked) & std_logic_vector(decoded_count(6 downto 0)) &
    "000" & decoded_valid & std_logic_vector(latest) & overflow_sticky &
    drop_sticky & busy & aligned;
end architecture;
