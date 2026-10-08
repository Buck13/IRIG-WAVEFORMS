library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity pcm_fm_tb is end;
architecture test of pcm_fm_tb is
 signal clk : std_logic := '0';
 signal reset, ce : std_logic := '0';
 signal nrz : signed(1 downto 0) := to_signed(1,2);
 signal io,qo : signed(15 downto 0);
 signal valid : std_logic;
 signal phase : unsigned(31 downto 0);
begin
 clk <= not clk after 5 ns;
 dut: entity work.pcm_fm_core port map(clk,reset,ce,nrz,io,qo,valid,phase);
 process
   file vectors : text;
   variable line_in : line;
   type item is record
     active : boolean;
     phase : std_logic_vector(31 downto 0);
     i,q : integer;
   end record;
   type queue_t is array(0 to 11) of item;
   variable queue : queue_t;
   variable symbol, ii, qq : integer;
   variable pp : std_logic_vector(31 downto 0);
   variable cycles, checked, total : natural := 0;
   variable rng : unsigned(15 downto 0) := x"BEEF";
   variable take : boolean;
   procedure clear_reset is
   begin
     wait until falling_edge(clk); reset<='1'; ce<='0';
     wait until rising_edge(clk); wait for 1 ns;
     assert valid='0' and phase=0 and io=16384 and qo=0 report "reset output mismatch" severity failure;
     for k in 0 to 11 loop queue(k).active:=false; end loop;
     wait until falling_edge(clk); reset<='0';
   end procedure;
 begin
   -- Deliberately discard samples in flight, then prove fresh reference alignment.
   clear_reset;
   for k in 0 to 4 loop
     wait until falling_edge(clk); ce<='1';
     wait until rising_edge(clk); wait for 1 ns;
   end loop;
   clear_reset;
   for case_id in 0 to 4 loop
     clear_reset;
     file_open(vectors,"case" & integer'image(case_id) & ".txt",read_mode);
     cycles:=0; checked:=0;
     loop
       wait until falling_edge(clk);
       for k in 11 downto 1 loop queue(k):=queue(k-1); end loop;
       queue(0).active:=false;
       rng := rng(14 downto 0) & (rng(15) xor rng(13) xor rng(12) xor rng(10));
       -- case0 continuously streams; others insert deterministic pseudo-random gaps.
       take := not endfile(vectors) and (case_id=0 or rng(1 downto 0)/="00");
       if take then
         readline(vectors,line_in);
         read(line_in,symbol); hread(line_in,pp); read(line_in,ii); read(line_in,qq);
         nrz<=to_signed(symbol,2); ce<='1';
         queue(0):=(true,pp,ii,qq);
       else ce<='0'; end if;
       wait until rising_edge(clk); wait for 1 ns;
       assert (valid='1')=queue(11).active report "valid/latency mismatch" severity failure;
       if queue(11).active then
         assert std_logic_vector(phase)=queue(11).phase report "phase mismatch" severity failure;
         assert to_integer(io)=queue(11).i and to_integer(qo)=queue(11).q
           report "I/Q mismatch at sample " & integer'image(checked) severity failure;
         checked:=checked+1; total:=total+1;
       end if;
       cycles:=cycles+1;
       if endfile(vectors) then
         take:=false;
         for k in 0 to 11 loop take:=take or queue(k).active; end loop;
         exit when not take;
       end if;
       assert cycles<400000 report "timeout" severity failure;
     end loop;
     file_close(vectors);
     report "CASE " & integer'image(case_id) & " PASS samples=" & integer'image(checked);
   end loop;
   report "PASS: PCM FM exact I/Q + phase + latency + stalls + reset; samples=" & integer'image(total);
   finish;
 end process;
end architecture;
