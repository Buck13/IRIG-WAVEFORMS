library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_trellis_scheduler is end;
architecture sim of tb_soqpsk_trellis_scheduler is
 signal clk:std_logic:='0'; signal reset,start,mv,busy,done,bit:std_logic:='0'; signal idx:unsigned(7 downto 0); signal m0,m1:signed(39 downto 0):=(others=>'0'); signal llr:signed(7 downto 0);
begin clk<=not clk after 5 ns; dut:entity work.soqpsk_trellis_scheduler port map(clk,reset,start,mv,m0,m1,idx,busy,done,bit,llr);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; start<='1'; wait until rising_edge(clk); start<='0'; mv<='1'; m0<=to_signed(1,40); m1<=to_signed(0,40); wait until rising_edge(clk); for k in 1 to 255 loop wait until rising_edge(clk); end loop; mv<='0'; wait for 1 ns; assert done='1' report "scheduler done missing" severity failure; report "PASS: SOQPSK scheduler smoke test" severity note; stop; wait; end process;
end architecture;
