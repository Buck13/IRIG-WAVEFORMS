library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_rx_core is end;
architecture sim of tb_soqpsk_rx_core is
 signal clk:std_logic:='0'; signal reset,sv,ss,ready,bv,bo,got:std_logic:='0'; signal obs:signed(15 downto 0):=(others=>'0'); signal llr:signed(7 downto 0);
begin clk<=not clk after 5 ns; dut:entity work.soqpsk_rx_core port map(clk,reset,sv,ss,'0',obs,ready,bv,bo,llr);
 process(clk) begin if rising_edge(clk) and bv='1' then got<='1'; end if; end process;
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; sv<='1'; for k in 0 to 7 loop obs<=to_signed(k*10,16); wait until rising_edge(clk); end loop; sv<='0'; wait for 25000 ns; assert got='1' report "core result missing" severity failure; report "PASS: SOQPSK receiver core smoke test" severity note; stop; wait; end process;
end architecture;
