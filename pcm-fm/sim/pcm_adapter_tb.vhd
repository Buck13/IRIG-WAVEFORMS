library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity pcm_adapter_tb is end;
architecture test of pcm_adapter_tb is
 signal clk : std_logic := '0';
 signal rst, sel, en, restart, req : std_logic := '0';
 signal selvec : std_logic_vector(0 downto 0);
 signal ei,eq : std_logic := '0';
 signal seed : std_logic_vector(14 downto 0) := (others=>'1');
 signal ti,tq,wi,wq : std_logic_vector(15 downto 0);
 signal valid,primed,fault : std_logic;
 signal di : std_logic_vector(15 downto 0) := x"1357";
 signal dq : std_logic_vector(15 downto 0) := x"ACE0";
begin
 clk<=not clk after 5 ns;
 selvec(0)<=sel;
 dut: entity work.pluto_pcm_fm_adapter port map(clk,rst,sel,en,restart,seed,req,di,dq,ti,tq,valid,primed,fault);
 wrapper: entity work.pluto_pcm_fm_top port map(clk,rst,selvec,ei,eq,req,di,dq,wi,wq);
 process
  file vec:text;
  variable line_in:line;
  variable symbol,i,q,count,total : integer:=0;
  variable p:std_logic_vector(31 downto 0);
  variable rng:unsigned(15 downto 0):=x"CAFE";
  variable requesting,was_primed:boolean;
  procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
 begin
  rst<='1';tick; wait until falling_edge(clk);rst<='0';
  for k in 0 to 5 loop
   tick;assert ti=di and tq=dq and wi=di and wq=dq report "DMA bypass" severity failure;
  end loop;
  for mode in 0 to 3 loop
   wait until falling_edge(clk);sel<='1'; en<='1';ei<='1';eq<='1';restart<='1';
   if mode=2 then seed<=std_logic_vector(to_unsigned(16#1234#,15));
   else seed<=(others=>'1');end if;
   -- Wrapper reset also restarts its fixed-seed source.
   rst<='1';req<='0';tick;
   wait until falling_edge(clk);rst<='0';restart<='0';
   if mode=0 or mode=3 then
    -- Exercise requests during startup; invalid startup samples must be zero.
    req<='1';
    for k in 0 to 27 loop
     tick;assert valid='0' and ti=x"0000" and tq=x"0000" report "startup" severity failure;
    end loop;
    wait until falling_edge(clk);req<='0';
   end if;
   for k in 0 to 65 loop tick;end loop;
   assert primed='1' and fault='0' report "prefill failed" severity failure;
   if mode=2 then file_open(vec,"case4.txt",read_mode);
   else file_open(vec,"case0.txt",read_mode);end if;
   count:=0;
   loop
    wait until falling_edge(clk);
    rng:=rng(14 downto 0)&(rng(15) xor rng(13) xor rng(12) xor rng(10));
    requesting:=mode=0 or rng(2 downto 0)="000" or (count mod 200)<80;
    if requesting then req<='1';else req<='0';end if;
    was_primed:=primed='1';tick;
    assert fault='0' report "underflow" severity failure;
    assert (valid='1')=requesting report "request capture" severity failure;
    if requesting then
     readline(vec,line_in);read(line_in,symbol);hread(line_in,p);read(line_in,i);read(line_in,q);
     assert signed(ti)=to_signed(i,16) and signed(tq)=to_signed(q,16)
      report "adapter sequence mismatch mode="&integer'image(mode)&" sample="&integer'image(count) severity failure;
     -- Modes with startup requests deliberately have differing top-level priming times.
     if mode=1 then
      assert wi=ti and wq=tq report "synchronized wrapper mismatch" severity failure;
     end if;
     count:=count+1;total:=total+1;
    end if;
    exit when endfile(vec) or (mode/=0 and count=2048);
   end loop;
   file_close(vec);
   report "ADAPTER CASE "&integer'image(mode)&" PASS samples="&integer'image(count);
   -- Test loss of either channel enable. Source clears, selected output zero.
   wait until falling_edge(clk);en<='0';ei<='0';req<='0';tick;
   assert ti=x"0000" and tq=x"0000" and wi=x"0000" and wq=x"0000" report "disable I" severity failure;
   wait until falling_edge(clk);ei<='1';eq<='0';tick;
   assert wi=x"0000" and wq=x"0000" report "disable Q" severity failure;
   wait until falling_edge(clk);sel<='0';
   for k in 0 to 5 loop tick;end loop;
   assert ti=di and tq=dq and wi=di and wq=dq report "return to DMA" severity failure;
  end loop;
  report "PASS: PCM ADAPTER FIFO PN15 requests gaps restart enables bypass; samples="&integer'image(total);
  finish;
 end process;
end;
