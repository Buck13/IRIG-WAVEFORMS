library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_cpm_survivor_traceback is end;
architecture test of tb_cpm_survivor_traceback is
  signal clk:std_logic:='0';signal reset,sv,sd,dv,busy:std_logic:='0';
  signal d0,d1:unsigned(7 downto 0):=(others=>'0');signal s0,s1,epoch,decoded:unsigned(1 downto 0):=(others=>'0');
  signal m0,m1:signed(47 downto 0):=(others=>'0');signal drive_done:std_logic:='0';
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_survivor_traceback port map(clk,reset,sv,d0,d1,s0,s1,m0,m1,sd,epoch,dv,decoded,busy);
  process
    file vectors:text open read_mode is "traceback_write_vectors.txt";variable l:line;
    variable n,e,vd0,vs0,vm0,vd1,vs1,vm1,last:integer;
  begin
    reset<='1';wait until rising_edge(clk);reset<='0';
    while not endfile(vectors) loop
      readline(vectors,l);read(l,n);read(l,e);read(l,vd0);read(l,vs0);read(l,vm0);read(l,vd1);read(l,vs1);read(l,vm1);read(l,last);
      wait until falling_edge(clk);sv<='1';d0<=to_unsigned(vd0,8);d1<=to_unsigned(vd1,8);s0<=to_unsigned(vs0,2);s1<=to_unsigned(vs1,2);m0<=to_signed(vm0,48);m1<=to_signed(vm1,48);epoch<=to_unsigned(e,2);
      wait until rising_edge(clk);
      if last=1 then wait until falling_edge(clk);sv<='0';sd<='1';wait until rising_edge(clk);wait until falling_edge(clk);sd<='0';end if;
    end loop;
    wait until falling_edge(clk);sv<='0';drive_done<='1';wait;
  end process;
  process
    file expected:text open read_mode is "traceback_decoded_vectors.txt";variable l:line;variable symbol,dibit,count:integer:=0;
  begin
    loop
      wait until rising_edge(clk);wait for 1 ns;
      if dv='1' then
        assert not endfile(expected) report "unexpected decoded output" severity failure;
        readline(expected,l);read(l,symbol);read(l,dibit);
        assert to_integer(decoded)=dibit report "traceback dibit mismatch at symbol "&integer'image(symbol) severity failure;
        count:=count+1;
      end if;
      if drive_done='1' and busy='0' then
        assert endfile(expected) report "missing decoded outputs" severity failure;
        assert count=9 report "decoded output count mismatch" severity failure;
        report "PASS: 9 bounded traceback dibits from 40 survivor rows" severity note;stop;wait;
      end if;
    end loop;
  end process;
end architecture;
