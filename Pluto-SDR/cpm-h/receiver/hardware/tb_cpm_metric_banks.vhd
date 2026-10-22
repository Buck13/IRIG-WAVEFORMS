library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.cpm_receiver_pkg.all;
entity tb_cpm_metric_banks is end;
architecture test of tb_cpm_metric_banks is
  signal clk:std_logic:='0';signal reset,lv,ss,wv,se,sw:std_logic:='0';
  signal li,wd0,wd1:unsigned(7 downto 0):=(others=>'0');signal lm,wm0,wm1:signed(47 downto 0):=(others=>'0');
  signal rp0,rp1:unsigned8_array4_t:=(others=>(others=>'0'));signal om0,om1:signed48_array4_t;
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_metric_banks port map(clk,reset,lv,li,lm,ss,rp0,rp1,om0,om1,wv,wd0,wd1,wm0,wm1,se,sw);
  process
    variable expected:integer;
  begin
    reset<='1';wait until rising_edge(clk);reset<='0';
    for i in 0 to 255 loop wait until falling_edge(clk);lv<='1';li<=to_unsigned(i,8);lm<=to_signed(i*10,48);wait until rising_edge(clk);end loop;
    wait until falling_edge(clk);lv<='0';ss<='1';wait until rising_edge(clk);wait until falling_edge(clk);ss<='0';wv<='1';
    for pair in 0 to 127 loop
      wd0<=to_unsigned(2*pair,8);wd1<=to_unsigned(2*pair+1,8);wm0<=to_signed(10000-6*pair,48);wm1<=to_signed(9997-6*pair,48);se<='1' when pair=127 else '0';wait until rising_edge(clk);
    end loop;
    wait for 1 ns;assert sw='1' report "bank did not swap" severity failure;
    wait until falling_edge(clk);wv<='0';se<='0';
    for k in 0 to 3 loop rp0(k)<=to_unsigned(k,8);rp1(k)<=to_unsigned(252+k,8);end loop;
    wait for 1 ns;
    -- Minimum is destination 255: 9235. Normalized metrics are raw-minimum.
    for k in 0 to 3 loop
      expected:=(10000-3*k)-9235;assert to_integer(om0(k))=expected report "low-index normalized metric mismatch" severity failure;
      expected:=(10000-3*(252+k))-9235;assert to_integer(om1(k))=expected report "high-index normalized metric mismatch" severity failure;
    end loop;
    report "PASS: ping-pong metric write, minimum and normalized read" severity note;stop;wait;
  end process;
end architecture;
