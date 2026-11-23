library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soqpsk_complex_correlator is
  generic(IQ_BITS:positive:=16; ACC_BITS:positive:=40);
  port(clk,reset,sample_valid,symbol_start,symbol_last:in std_logic;
       rx_i,rx_q,template_i,template_q:in signed(IQ_BITS-1 downto 0);
       result_valid:out std_logic;
       result_re,result_im:out signed(ACC_BITS-1 downto 0));
end entity;

architecture rtl of soqpsk_complex_correlator is
 signal acc_re,acc_im:signed(ACC_BITS-1 downto 0):=(others=>'0');
begin
 process(clk)
  variable ii,qq,qi,iq:signed(2*IQ_BITS-1 downto 0);
  variable re_term,im_term,total_re,total_im:signed(ACC_BITS-1 downto 0);
 begin
  if rising_edge(clk) then
   result_valid<='0';
   if reset='1' then acc_re<=(others=>'0'); acc_im<=(others=>'0'); result_re<=(others=>'0'); result_im<=(others=>'0');
   elsif sample_valid='1' then
    ii:=rx_i*template_i; qq:=rx_q*template_q; qi:=rx_q*template_i; iq:=rx_i*template_q;
    re_term:=resize(ii,ACC_BITS)+resize(qq,ACC_BITS);
    im_term:=resize(qi,ACC_BITS)-resize(iq,ACC_BITS);
    if symbol_start='1' then total_re:=re_term; total_im:=im_term; else total_re:=acc_re+re_term; total_im:=acc_im+im_term; end if;
    acc_re<=total_re; acc_im<=total_im;
    if symbol_last='1' then result_re<=total_re; result_im<=total_im; result_valid<='1'; end if;
   end if;
  end if;
 end process;
end architecture;
