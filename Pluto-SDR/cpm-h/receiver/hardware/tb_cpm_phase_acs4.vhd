library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.cpm_receiver_pkg.all;
entity tb_cpm_phase_acs4 is end;
architecture test of tb_cpm_phase_acs4 is
  signal clk:std_logic:='0';signal reset,iv,ov:std_logic:='0';
  signal old:signed48_array4_t;signal cr,ci:signed18_array4_t;signal p:phase_array4_t;
  signal metric:signed(47 downto 0);signal survivor:unsigned(1 downto 0);
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_phase_acs4 port map(clk,reset,iv,old,cr,ci,p,ov,metric,survivor);
  process
    file vectors:text open read_mode is "phase_acs_vectors.txt";variable l:line;
    variable vo,vcr,vci,vp,expected,win,count:integer:=0;
  begin
    reset<='1';wait until rising_edge(clk);reset<='0';
    while not endfile(vectors) loop
      readline(vectors,l);
      for k in 0 to 3 loop
        read(l,vo);read(l,vcr);read(l,vci);read(l,vp);
        old(k)<=to_signed(vo,48);cr(k)<=to_signed(vcr,18);ci(k)<=to_signed(vci,18);p(k)<=to_unsigned(vp,5);
      end loop;read(l,expected);read(l,win);
      wait until falling_edge(clk);iv<='1';wait until rising_edge(clk);wait until falling_edge(clk);iv<='0';
      loop wait until rising_edge(clk);wait for 1 ns;exit when ov='1';end loop;
      assert ov='1' report "output_valid mismatch" severity failure;
      assert to_integer(metric)=expected report "metric mismatch at vector "&integer'image(count) severity failure;
      assert to_integer(survivor)=win report "survivor mismatch at vector "&integer'image(count) severity failure;
      count:=count+1;
    end loop;
    report "PASS: "&integer'image(count)&" phase/ACS vectors" severity note;stop;wait;
  end process;
end architecture;
