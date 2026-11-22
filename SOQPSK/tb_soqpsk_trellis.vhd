library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_soqpsk_trellis is end;
architecture sim of tb_soqpsk_trellis is
 signal clk:std_logic:='0'; signal reset,valid,bv,bout:std_logic:='0';
 signal obs:signed(11 downto 0):=(others=>'0'); signal llr:signed(7 downto 0);
begin
 clk<=not clk after 5 ns;
 dut:entity work.soqpsk_trellis port map(clk,reset,valid,obs,bv,bout,llr);
 process
 begin
  reset<='1'; wait until rising_edge(clk); reset<='0'; valid<='1'; obs<=to_signed(256,12); wait until rising_edge(clk); wait for 1 ns;
  assert bv='1' report "trellis output missing" severity failure;
  assert bout='1' report "trellis decision mismatch" severity failure;
  assert llr<0 report "trellis LLR sign mismatch" severity failure;
  report "PASS: SOQPSK trellis smoke test" severity note; stop; wait;
 end process;
end architecture;
