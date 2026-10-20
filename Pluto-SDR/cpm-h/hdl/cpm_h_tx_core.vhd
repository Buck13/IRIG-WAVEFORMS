library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_rom_pkg.all;

entity cpm_h_tx_core is
  port (
    clk, reset, sample_ce : in std_logic;
    dibit : in std_logic_vector(1 downto 0);
    dibit_valid : in std_logic;
    dibit_ready : out std_logic;
    iq_valid : out std_logic;
    i_out, q_out : out signed(15 downto 0)
  );
end entity;

architecture rtl of cpm_h_tx_core is
  signal phase_valid : std_logic;
  signal phase : unsigned(PHASE_BITS-1 downto 0);
begin
  phase_core : entity work.cpm_h_phase_core
    port map (clk, reset, sample_ce, dibit, dibit_valid, dibit_ready,
              phase_valid, open, phase);
  nco : entity work.cpm_h_iq_rom
    port map (clk, reset, phase_valid, phase, iq_valid, i_out, q_out);
end architecture;
