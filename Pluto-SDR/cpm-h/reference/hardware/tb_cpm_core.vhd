library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.cpm_rom_pkg.all;

entity tb_cpm_core is end;
architecture test of tb_cpm_core is
  signal clk : std_logic := '0';
  signal reset, ce, valid, ready, ov : std_logic := '0';
  signal dibit : std_logic_vector(1 downto 0) := "00";
  signal delta : signed(PHASE_BITS-1 downto 0);
  signal phase : unsigned(PHASE_BITS-1 downto 0);
  function bit_of(n : integer) return std_logic is
  begin
    if n = 0 then return '0'; else return '1'; end if;
  end;
begin
  clk <= not clk after 5 ns;
  dut: entity work.cpm_core port map(clk, reset, ce, dibit, valid, ready, ov, delta, phase);
  process
    file vectors : text open read_mode is "vectors.txt";
    variable l : line;
    variable r, c, v, d, er, eo, ei, ep : integer;
    variable cycle : integer := 0;
  begin
    while not endfile(vectors) loop
      readline(vectors, l);
      read(l,r); read(l,c); read(l,v); read(l,d);
      read(l,er); read(l,eo); read(l,ei); read(l,ep);
      wait until falling_edge(clk);
      reset <= bit_of(r); ce <= bit_of(c); valid <= bit_of(v);
      dibit <= std_logic_vector(to_unsigned(d, 2));
      wait for 1 ns;
      assert ready = bit_of(er) report "ready mismatch at cycle " & integer'image(cycle) severity failure;
      wait until rising_edge(clk);
      wait for 1 ns;
      assert ov = bit_of(eo) report "valid mismatch at cycle " & integer'image(cycle) severity failure;
      if eo = 1 then
        assert to_integer(delta) = ei report "delta mismatch at cycle " & integer'image(cycle) severity failure;
        assert to_integer(phase) = ep report "phase mismatch at cycle " & integer'image(cycle) severity failure;
      end if;
      cycle := cycle+1;
    end loop;
    report "PASS: " & integer'image(cycle) & " clock vectors" severity note;
    stop;
    wait;
  end process;
end architecture;
