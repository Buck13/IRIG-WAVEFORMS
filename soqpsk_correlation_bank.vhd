library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soqpsk_template_pkg.all;

-- Two-branch SOQPSK correlation lane. The input observation is the signed
-- phase/frequency sample produced by the carrier/FIR front end.
entity soqpsk_correlation_bank is
  generic (OBS_BITS:positive:=16; ACC_BITS:positive:=40);
  port(clk,reset,sample_valid,symbol_start,symbol_last:in std_logic;
       parity:in std_logic; state:in unsigned(7 downto 0);
       observation:in signed(OBS_BITS-1 downto 0);
       result_valid:out std_logic;
       metric0,metric1:out signed(ACC_BITS-1 downto 0));
end entity;

architecture rtl of soqpsk_correlation_bank is
 signal acc0,acc1:signed(ACC_BITS-1 downto 0):=(others=>'0');
 signal sample_index:natural range 0 to SPS-1:=0;
begin
 process(clk)
   variable c0,c1:signed(OBS_BITS-1 downto 0);
   variable p0,p1:signed(2*OBS_BITS-1 downto 0);
   variable n0,n1:signed(ACC_BITS-1 downto 0);
   variable par_i,st_i:integer;
 begin
  if rising_edge(clk) then
   result_valid<='0';
   if reset='1' then acc0<=(others=>'0'); acc1<=(others=>'0'); sample_index<=0; metric0<=(others=>'0'); metric1<=(others=>'0');
   elsif sample_valid='1' then
    if parity='1' then par_i:=1; else par_i:=0; end if; st_i:=to_integer(state);
    c0:=to_signed(TEMPLATE(template_index(st_i,0,sample_index,par_i)),OBS_BITS);
    c1:=to_signed(TEMPLATE(template_index(st_i,1,sample_index,par_i)),OBS_BITS);
    p0:=observation*c0; p1:=observation*c1;
    if symbol_start='1' then n0:=resize(p0,ACC_BITS); n1:=resize(p1,ACC_BITS); else n0:=acc0+resize(p0,ACC_BITS); n1:=acc1+resize(p1,ACC_BITS); end if;
    acc0<=n0; acc1<=n1;
    if symbol_last='1' then metric0<=n0; metric1<=n1; result_valid<='1'; sample_index<=0; else sample_index<=sample_index+1; end if;
   end if;
  end if;
 end process;
end architecture;
