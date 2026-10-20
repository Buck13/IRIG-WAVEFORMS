-- Pipelined ARTM multi-h CPM phase core. Arithmetic is bit-exact to cpm_core.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_rom_pkg.all;

entity cpm_h_phase_core is
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

architecture rtl of cpm_h_phase_core is
  signal m : integer range 0 to SPS-1 := 0;
  signal w0, w1, w2 : integer range -15 to 15 := 0;
  signal next_h : integer range 4 to 5 := 4;
  signal s0_w0, s0_w1, s0_w2 : integer range -15 to 15 := 0;
  signal s0_m : integer range 0 to SPS-1 := 0;
  signal s0_valid : std_logic := '0';
  signal s1_b0, s1_b1, s1_b2 : integer range -983025 to 983025 := 0;
  signal s1_valid : std_logic := '0';
  signal accumulator : unsigned(PHASE_BITS-1 downto 0) := (others => '0');
begin
  dibit_ready <= '1' when m = 0 else '0';
  process(clk)
    variable a : integer range -3 to 3;
    variable v0, v1, v2 : integer range -15 to 15;
    variable total : integer range -2949075 to 2949075;
  begin
    if rising_edge(clk) then
      out_valid <= '0';
      if reset = '1' then
        m <= 0; w0 <= 0; w1 <= 0; w2 <= 0; next_h <= 4;
        s0_valid <= '0'; s1_valid <= '0';
        accumulator <= (others => '0');
        phase_word <= (others => '0'); delta_word <= (others => '0');
      else
        -- Stage 2: ordered phase accumulation. Once primed, accepts one delta/clock.
        if s1_valid = '1' then
          total := s1_b0 + s1_b1 + s1_b2;
          delta_word <= to_signed(total, PHASE_BITS);
          phase_word <= accumulator;
          accumulator <= accumulator + unsigned(to_signed(total, PHASE_BITS));
          out_valid <= '1';
        end if;

        -- Stage 1: isolate the three ROM/multiply paths from the final adder.
        s1_valid <= s0_valid;
        if s0_valid = '1' then
          s1_b0 <= s0_w0 * AREA_ROM(s0_m);
          s1_b1 <= s0_w1 * AREA_ROM(SPS+s0_m);
          s1_b2 <= s0_w2 * AREA_ROM(2*SPS+s0_m);
        end if;

        -- Stage 0: accept waveform time and capture the effective symbol history.
        s0_valid <= '0';
        if sample_ce = '1' and (m /= 0 or dibit_valid = '1') then
          v0 := w0; v1 := w1; v2 := w2;
          if m = 0 then
            case dibit is
              when "00" => a := -3;
              when "01" => a := -1;
              when "10" => a := 1;
              when "11" => a := 3;
              when others => a := 0;
            end case;
            v2 := w1; v1 := w0; v0 := a*next_h;
            w2 <= v2; w1 <= v1; w0 <= v0;
            next_h <= 9-next_h;
          end if;
          s0_w0 <= v0; s0_w1 <= v1; s0_w2 <= v2; s0_m <= m;
          s0_valid <= '1';
          if m = SPS-1 then m <= 0; else m <= m+1; end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
