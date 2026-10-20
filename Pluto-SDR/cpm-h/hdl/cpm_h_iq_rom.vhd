library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_rom_pkg.all;
use work.cpm_h_nco_pkg.all;

entity cpm_h_iq_rom is
  port (
    clk, reset : in std_logic;
    phase_valid : in std_logic;
    phase_word : in unsigned(PHASE_BITS-1 downto 0);
    iq_valid : out std_logic;
    i_out, q_out : out signed(15 downto 0)
  );
end entity;

architecture rtl of cpm_h_iq_rom is
  constant ROM : sine_rom_t := SINE_ROM;
  attribute rom_style : string;
  attribute rom_style of ROM : constant is "block";
begin
  process(clk)
    variable q_addr, i_addr : integer range 0 to NCO_SIZE-1;
  begin
    if rising_edge(clk) then
      iq_valid <= '0';
      if reset = '1' then
        i_out <= (others => '0'); q_out <= (others => '0');
      elsif phase_valid = '1' then
        q_addr := to_integer(phase_word(PHASE_BITS-1 downto PHASE_BITS-NCO_ADDR_BITS));
        i_addr := (q_addr + NCO_SIZE/4) mod NCO_SIZE;
        i_out <= to_signed(ROM(i_addr), 16);
        q_out <= to_signed(ROM(q_addr), 16);
        iq_valid <= '1';
      end if;
    end if;
  end process;
end architecture;
