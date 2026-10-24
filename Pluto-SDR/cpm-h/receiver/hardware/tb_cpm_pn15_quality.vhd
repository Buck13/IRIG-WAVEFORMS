library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_cpm_pn15_quality is end;
architecture sim of tb_cpm_pn15_quality is
  signal clk:std_logic:='0';
  signal reset,valid,done:std_logic:='0';
  signal dibit:unsigned(1 downto 0):=(others=>'0');
  signal errors,checked:unsigned(6 downto 0);
  function step(v:std_logic_vector(14 downto 0)) return std_logic_vector is
  begin return (v(14) xor v(0)) & v(14 downto 1);end function;
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_pn15_quality port map(clk,reset,valid,dibit,done,errors,checked);
  process
    variable state,one:std_logic_vector(14 downto 0):=(others=>'1');
  begin
    reset<='1';wait until rising_edge(clk);reset<='0';
    for n in 0 to 39 loop
      one:=step(state);dibit(1)<=state(0);dibit(0)<=one(0);valid<='1';
      wait until rising_edge(clk);valid<='0';state:=step(one);
      wait until rising_edge(clk);
    end loop;
    assert done='1' and checked=64 and errors=0 report "valid PN15 quality mismatch" severity failure;

    reset<='1';wait until rising_edge(clk);reset<='0';state:=(others=>'1');
    for n in 0 to 39 loop
      one:=step(state);dibit(1)<=not state(0);dibit(0)<=not one(0);valid<='1';
      wait until rising_edge(clk);valid<='0';state:=step(one);
      wait until rising_edge(clk);
    end loop;
    assert done='1' and checked=64 and errors=64 report "inverted PN15 quality mismatch" severity failure;
    report "PASS: PN15 self-synchronizing quality scorer" severity note;stop;wait;
  end process;
end architecture;
