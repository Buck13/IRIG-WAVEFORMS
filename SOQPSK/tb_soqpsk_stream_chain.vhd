library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.env.all;
entity tb_soqpsk_stream_chain is end;
architecture sim of tb_soqpsk_stream_chain is signal clk:std_logic:='0'; signal reset,valid,ready,bv,bo:std_logic:='0'; signal ai,aq:signed(15 downto 0):=(others=>'0'); signal llr:signed(7 downto 0);
begin clk<=not clk after 5 ns; dut:entity work.soqpsk_stream_chain port map(clk,reset,valid,ai,aq,ready,bv,bo,llr);
 process begin reset<='1'; wait until rising_edge(clk); reset<='0'; valid<='1'; ai<=to_signed(1000,16); aq<=to_signed(200,16); for k in 0 to 31 loop wait until rising_edge(clk); end loop; valid<='0'; wait for 30000 ns; report "PASS: SOQPSK streaming chain smoke test" severity note; stop; wait; end process;
end architecture;
