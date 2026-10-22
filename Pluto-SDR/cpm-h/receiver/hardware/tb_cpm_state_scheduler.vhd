library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
entity tb_cpm_state_scheduler is end;
architecture test of tb_cpm_state_scheduler is
  signal clk:std_logic:='0';signal reset,start,jv,done:std_logic:='0';signal epoch:unsigned(1 downto 0):=(others=>'0');
  signal d0,d1,p0,p1,p2,p3,u0,u1,u2,u3:unsigned(7 downto 0);
  signal c0,c1,c2,c3,v0,v1,v2,v3:unsigned(5 downto 0);
  signal h0,h1,h2,h3,w0,w1,w2,w3:unsigned(4 downto 0);
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_state_scheduler port map(clk,reset,start,epoch,jv,d0,d1,
    p0,p1,p2,p3,c0,c1,c2,c3,h0,h1,h2,h3,u0,u1,u2,u3,v0,v1,v2,v3,w0,w1,w2,w3,done);
  process
    file vectors:text open read_mode is "scheduler_vectors.txt";variable l:line;
    variable ee,cc,ed0,ed1:integer;type ints is array(0 to 3) of integer;
    variable ep0,ec0,eh0,ep1,ec1,eh1:ints;variable count:integer:=0;
  begin
    reset<='1';wait until rising_edge(clk);reset<='0';
    for e in 0 to 3 loop
      wait until falling_edge(clk);epoch<=to_unsigned(e,2);start<='1';
      wait until rising_edge(clk);wait until falling_edge(clk);start<='0';
      for cyc in 0 to 127 loop
        readline(vectors,l);read(l,ee);read(l,cc);read(l,ed0);
        for k in 0 to 3 loop read(l,ep0(k));read(l,ec0(k));read(l,eh0(k));end loop;
        read(l,ed1);for k in 0 to 3 loop read(l,ep1(k));read(l,ec1(k));read(l,eh1(k));end loop;
        wait until rising_edge(clk);wait for 1 ns;
        assert jv='1' and ee=e and cc=cyc report "job timing mismatch" severity failure;
        assert to_integer(d0)=ed0 and to_integer(d1)=ed1 report "destination mismatch" severity failure;
        assert to_integer(p0)=ep0(0) and to_integer(p1)=ep0(1) and to_integer(p2)=ep0(2) and to_integer(p3)=ep0(3) report "lane0 predecessor mismatch" severity failure;
        assert to_integer(c0)=ec0(0) and to_integer(c1)=ec0(1) and to_integer(c2)=ec0(2) and to_integer(c3)=ec0(3) report "lane0 correlation mismatch" severity failure;
        assert to_integer(h0)=eh0(0) and to_integer(h1)=eh0(1) and to_integer(h2)=eh0(2) and to_integer(h3)=eh0(3) report "lane0 phase mismatch" severity failure;
        assert to_integer(u0)=ep1(0) and to_integer(u1)=ep1(1) and to_integer(u2)=ep1(2) and to_integer(u3)=ep1(3) report "lane1 predecessor mismatch" severity failure;
        assert to_integer(v0)=ec1(0) and to_integer(v1)=ec1(1) and to_integer(v2)=ec1(2) and to_integer(v3)=ec1(3) report "lane1 correlation mismatch" severity failure;
        assert to_integer(w0)=eh1(0) and to_integer(w1)=eh1(1) and to_integer(w2)=eh1(2) and to_integer(w3)=eh1(3) report "lane1 phase mismatch" severity failure;
        if cyc=127 then assert done='1' report "missing done" severity failure;end if;count:=count+1;
      end loop;
    end loop;
    report "PASS: "&integer'image(count)&" two-lane scheduler jobs" severity note;stop;wait;
  end process;
end architecture;
