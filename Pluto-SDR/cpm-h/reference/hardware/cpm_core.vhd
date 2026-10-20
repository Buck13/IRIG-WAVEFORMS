-- VHDL-2008 teaching core: three concurrent pulse sections and phase accumulator.
-- Combinational ROM reads + multipliers + summer in one clock path.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_rom_pkg.all;

entity cpm_core is
  port (
    clk, reset, sample_ce : in std_logic;
    dibit : in std_logic_vector(1 downto 0);
    dibit_valid : in std_logic;
    dibit_ready : out std_logic;
    out_valid : out std_logic;
    delta_word : out signed(PHASE_BITS-1 downto 0);
    phase_word : out unsigned(PHASE_BITS-1 downto 0)
  );
end entity;

architecture rtl of cpm_core is
  signal m : integer range 0 to SPS-1 := 0;
  signal w0, w1, w2 : integer range -15 to 15 := 0;
  signal next_h : integer range 4 to 5 := 4;
  signal accumulator : unsigned(PHASE_BITS-1 downto 0) := (others => '0');
begin
  dibit_ready <= '1' when m = 0 else '0';
  process(clk)
    variable a : integer range -3 to 3;
    variable v0, v1, v2 : integer range -15 to 15;
    variable b0, b1, b2 : integer range -983025 to 983025;
    variable total : integer range -2949075 to 2949075;
  begin
    if rising_edge(clk) then
      out_valid <= '0';
      if reset = '1' then
        m <= 0; w0 <= 0; w1 <= 0; w2 <= 0; next_h <= 4;
        accumulator <= (others => '0');
        phase_word <= (others => '0'); delta_word <= (others => '0');
      elsif sample_ce = '1' and (m /= 0 or dibit_valid = '1') then
        v0 := w0; v1 := w1; v2 := w2;
        if m = 0 then
          case dibit is
            when "00" => a := -3;
            when "01" => a := -1;
            when "10" => a := 1;
            when "11" => a := 3;
            when others => a := 0; -- simulation unknowns, not a valid input
          end case;
          v2 := w1; v1 := w0; v0 := a*next_h;
          w2 <= v2; w1 <= v1; w0 <= v0;
          next_h <= 9-next_h;
        end if;
        -- All three products describe the same output sample.
        b0 := v0*AREA_ROM(m);
        b1 := v1*AREA_ROM(SPS+m);
        b2 := v2*AREA_ROM(2*SPS+m);
        total := b0+b1+b2;
        delta_word <= to_signed(total, PHASE_BITS);
        -- Output phase at START of this interval, then integrate its area.
        phase_word <= accumulator;
        accumulator <= accumulator + unsigned(to_signed(total, PHASE_BITS));
        out_valid <= '1';
        if m = SPS-1 then m <= 0; else m <= m+1; end if;
      end if;
    end if;
  end process;
end architecture;
