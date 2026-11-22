library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_fir is end; architecture sim of tb_soqpsk_fir is
 signal clk:std_logic:='0'; signal reset,valid,vo:std_logic:='0'; signal si:signed(15 downto 0):=(others=>'0'); signal so:signed(31 downto 0);
begin clk<=not clk after 5 ns; dut:entity work.soqpsk_fir port map(clk,reset,valid,si,vo,so);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; valid<='1'; si<=to_signed(1000,16); wait until rising_edge(clk); wait for 1 ns; assert vo='1' report "FIR valid missing" severity failure; report "PASS: SOQPSK FIR smoke test" severity note; stop; wait; end process;
end architecture;
