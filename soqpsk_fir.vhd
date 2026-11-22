library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soqpsk_pulse_pkg.all;
entity soqpsk_fir is
  generic (IN_BITS:positive:=16; OUT_BITS:positive:=32);
  port(clk,reset,valid:in std_logic; sample_in:in signed(IN_BITS-1 downto 0);
       valid_out:out std_logic; sample_out:out signed(OUT_BITS-1 downto 0));
end entity;
architecture rtl of soqpsk_fir is
  type hist_t is array(0 to TAPS-1) of signed(IN_BITS-1 downto 0);
  signal hist:hist_t := (others=>(others=>'0'));
begin
 process(clk)
   variable acc: signed(OUT_BITS-1 downto 0);
   variable prod: signed(2*IN_BITS-1 downto 0);
 begin
  if rising_edge(clk) then
   valid_out<='0';
   if reset='1' then hist<=(others=>(others=>'0')); sample_out<=(others=>'0');
   elsif valid='1' then
    for k in TAPS-1 downto 1 loop hist(k)<=hist(k-1); end loop; hist(0)<=sample_in;
    acc:= (others=>'0');
    for k in 0 to TAPS-1 loop prod:=to_signed(PULSE(k),IN_BITS)*hist(k); acc:=acc+resize(prod,OUT_BITS); end loop;
    sample_out<=acc; valid_out<='1';
   end if;
  end if;
 end process;
end architecture;
