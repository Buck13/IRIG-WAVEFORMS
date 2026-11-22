library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_rx_adapter is end;
architecture sim of tb_soqpsk_rx_adapter is
 signal clk:std_logic:='0'; signal reset,enable,restart,vi,vq,ready,sv,ss,sl,al,drop:std_logic:='0';
 signal off:unsigned(3 downto 0):=(others=>'0'); signal ai,aq,si,sq:signed(15 downto 0):=(others=>'0'); signal idx:unsigned(7 downto 0);
begin clk<=not clk after 5 ns; enable<='1'; ready<='1'; vi<= '1'; vq<='1';
 dut:entity work.soqpsk_rx_adapter port map(clk,reset,enable,restart,off,vi,vq,ai,aq,ready,sv,ss,sl,al,drop,si,sq,idx);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; wait until rising_edge(clk); wait for 1 ns; assert sv='1' report "adapter sample missing" severity failure; assert ss='1' report "adapter symbol start missing" severity failure; report "PASS: SOQPSK adapter smoke test" severity note; stop; wait; end process;
end architecture;
