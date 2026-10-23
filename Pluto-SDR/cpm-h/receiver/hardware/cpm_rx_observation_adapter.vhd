library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Manual acquisition boundary for the first Pluto receiver image.
-- The input is a 32-sample/dibit stream already transferred into clk.
entity cpm_rx_observation_adapter is
  port(
    clk,reset : in std_logic;
    enable,restart : in std_logic;
    timing_offset : in unsigned(4 downto 0);
    start_epoch : in unsigned(1 downto 0);
    adc_valid_i,adc_valid_q : in std_logic;
    adc_i,adc_q : in std_logic_vector(15 downto 0);
    detector_ready : in std_logic;
    observation_valid : out std_logic;
    symbol_start : out std_logic;
    observation_i,observation_q : out signed(11 downto 0);
    epoch : out unsigned(1 downto 0);
    aligned : out std_logic;
    dropped_observation : out std_logic
  );
end entity;

architecture rtl of cpm_rx_observation_adapter is
  signal searching : std_logic := '1';
  signal raw_position : unsigned(4 downto 0) := (others=>'0');
  signal decimate_phase : std_logic := '0';
  signal observation_index : unsigned(3 downto 0) := (others=>'0');
  signal epoch_q : unsigned(1 downto 0) := (others=>'0');
begin
  epoch<=epoch_q;
  aligned<=not searching;

  process(clk)
    variable selected : boolean;
  begin
    if rising_edge(clk) then
      observation_valid<='0'; symbol_start<='0'; dropped_observation<='0';
      if reset='1' or restart='1' or enable='0' then
        searching<='1'; raw_position<=(others=>'0'); decimate_phase<='0';
        observation_index<=(others=>'0'); epoch_q<=start_epoch;
        observation_i<=(others=>'0'); observation_q<=(others=>'0');
      elsif adc_valid_i='1' and adc_valid_q='1' then
        selected:=false;
        if searching='1' then
          if raw_position=timing_offset then
            searching<='0'; decimate_phase<='0'; selected:=true;
            observation_index<=(others=>'0'); epoch_q<=start_epoch;
          end if;
          raw_position<=raw_position+1;
        else
          if decimate_phase='1' then selected:=true; end if;
          decimate_phase<=not decimate_phase;
        end if;

        if selected then
          if detector_ready='1' then
            observation_i<=signed(adc_i(11 downto 0));
            observation_q<=signed(adc_q(11 downto 0));
            observation_valid<='1';
            if observation_index=0 then symbol_start<='1'; end if;
          else
            dropped_observation<='1';
          end if;
          if observation_index=15 then
            observation_index<=(others=>'0'); epoch_q<=epoch_q+1;
          else observation_index<=observation_index+1; end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
