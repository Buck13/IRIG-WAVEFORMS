library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_sync_blocks is end;
architecture sim of tb_soqpsk_sync_blocks is
 signal clk:std_logic:='0'; signal reset,valid,vn,vi,vt:std_logic:='0'; signal ii,qq:signed(15 downto 0):=(others=>'0'); signal i32,q32,io,qo:signed(31 downto 0); signal ph:unsigned(7 downto 0); signal ce:signed(31 downto 0); signal tick:std_logic; signal te:signed(31 downto 0);
begin clk<=not clk after 5 ns;
 nco:entity work.soqpsk_carrier_nco port map(clk,reset,valid,ii,qq,ph,i32,q32,vn);
 loop0:entity work.soqpsk_carrier_loop port map(clk,reset,vn,i32,q32,ph,ce);
 ted:entity work.soqpsk_timing_ted port map(clk,reset,vn,i32,q32,tick,te);
 intp:entity work.soqpsk_linear_interp port map(clk,reset,vn,to_unsigned(128,8),i32,q32,io,qo,vi);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; valid<='1'; ii<=to_signed(1000,16); qq<=to_signed(200,16); for k in 0 to 15 loop wait until rising_edge(clk); end loop; valid<='0'; wait for 1 ns; assert vi='1' report "sync valid missing" severity failure; report "PASS: SOQPSK sync blocks smoke test" severity note; stop; wait; end process;
end architecture;
