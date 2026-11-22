library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_correlation_bank is end;
architecture sim of tb_soqpsk_correlation_bank is
 signal clk:std_logic:='0'; signal reset,sv,ss,sl,p,rv:std_logic:='0'; signal st:unsigned(7 downto 0):=(others=>'0'); signal obs:signed(15 downto 0):=(others=>'0'); signal m0,m1:signed(39 downto 0);
begin clk<=not clk after 5 ns; dut:entity work.soqpsk_correlation_bank port map(clk,reset,sv,ss,sl,p,st,obs,rv,m0,m1);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; sv<='1'; ss<='1'; obs<=to_signed(100,16); wait until rising_edge(clk); ss<='0'; for k in 1 to 6 loop wait until rising_edge(clk); end loop; sl<='1'; wait until rising_edge(clk); wait for 1 ns; assert rv='1' report "correlation result missing" severity failure; report "PASS: SOQPSK correlation bank smoke test" severity note; stop; wait; end process;
end architecture;
