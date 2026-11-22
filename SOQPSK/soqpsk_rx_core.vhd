library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soqpsk_rx_core is
  port(clk,reset,sample_valid,symbol_start:in std_logic;
       parity:in std_logic; observation:in signed(15 downto 0);
       sample_ready,bit_valid,bit_out:out std_logic; llr:out signed(7 downto 0));
end entity;

architecture rtl of soqpsk_rx_core is
  type sample_mem is array(0 to 7) of signed(15 downto 0);
  signal buf:sample_mem:=(others=>(others=>'0')); signal in_count:natural range 0 to 7:=0;
  signal processing,bank_active,bank_valid,bank_start,bank_last:std_logic:='0';
  signal bank_count:natural range 0 to 7:=0; signal state:unsigned(7 downto 0);
  signal m0,m1:signed(39 downto 0); signal sched_busy,sched_done:std_logic;
  signal sched_start:std_logic:='0'; signal sched_bit:std_logic; signal sched_llr:signed(7 downto 0);
begin
 sample_ready<=not processing;
 bit_valid<=sched_done; bit_out<=sched_bit; llr<=sched_llr;
 bank_start<='1' when bank_active='1' and bank_count=0 else '0';
 bank_last<='1' when bank_active='1' and bank_count=7 else '0';
 bank:entity work.soqpsk_correlation_bank
   port map(clk,reset,bank_active,bank_start,bank_last,parity,state,buf(bank_count),bank_valid,m0,m1);
 sched:entity work.soqpsk_trellis_scheduler
   port map(clk,reset,sched_start,bank_valid,m0,m1,state,sched_busy,sched_done,sched_bit,sched_llr);
 process(clk)
 begin
  if rising_edge(clk) then
   sched_start<='0';
   if reset='1' then processing<='0'; bank_active<='0'; in_count<=0; bank_count<=0;
   else
    if sample_valid='1' and processing='0' then
     buf(in_count)<=observation;
     if in_count=7 then processing<='1'; sched_start<='1'; bank_active<='1'; bank_count<=0; in_count<=0;
     else in_count<=in_count+1; end if;
    end if;
    if bank_active='1' then
     if bank_count=7 then bank_active<='0'; bank_count<=0;
     else bank_count<=bank_count+1; end if;
    elsif sched_busy='1' and bank_valid='1' then
     bank_active<='1'; bank_count<=0;
    end if;
    if sched_done='1' then processing<='0'; end if;
   end if;
  end if;
 end process;
end architecture;
