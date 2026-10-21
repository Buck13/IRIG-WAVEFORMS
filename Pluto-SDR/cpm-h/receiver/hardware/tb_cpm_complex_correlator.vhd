library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
entity tb_cpm_complex_correlator is end;
architecture test of tb_cpm_complex_correlator is
  signal clk:std_logic:='0'; signal reset,valid,first,last,cv:std_logic:='0';
  signal ri,rq,ti,tq:signed(11 downto 0):=(others=>'0');
  signal cr,ci:signed(31 downto 0);
  function bit_of(n:integer)return std_logic is begin if n=0 then return '0'; else return '1'; end if; end;
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_complex_correlator port map(clk,reset,valid,first,last,ri,rq,ti,tq,cv,cr,ci);
  process
    file vectors:text open read_mode is "correlation_vectors.txt"; variable l:line;
    variable f,z,vi,vq,wi,wq,er,ei,count:integer:=0;
  begin
    reset<='1'; wait until rising_edge(clk); reset<='0';
    while not endfile(vectors) loop
      readline(vectors,l); read(l,f);read(l,z);read(l,vi);read(l,vq);read(l,wi);read(l,wq);read(l,er);read(l,ei);
      wait until falling_edge(clk); valid<='1';first<=bit_of(f);last<=bit_of(z);
      ri<=to_signed(vi,12);rq<=to_signed(vq,12);ti<=to_signed(wi,12);tq<=to_signed(wq,12);
      wait until rising_edge(clk);wait for 1 ns;
      assert cv=bit_of(z) report "correlation_valid mismatch" severity failure;
      if z=1 then
        assert to_integer(cr)=er report "real correlation mismatch" severity failure;
        assert to_integer(ci)=ei report "imag correlation mismatch" severity failure;
      end if; count:=count+1;
    end loop;
    report "PASS: "&integer'image(count)&" correlation samples" severity note; stop;wait;
  end process;
end architecture;
