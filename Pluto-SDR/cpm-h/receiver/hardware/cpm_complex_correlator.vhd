-- One reusable complex correlation lane: sum(rx * conjugate(template)).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_complex_correlator is
  generic (IQ_BITS:positive:=12; ACC_BITS:positive:=32);
  port (
    clk,reset,sample_valid,symbol_start,symbol_last:in std_logic;
    rx_i,rx_q,template_i,template_q:in signed(IQ_BITS-1 downto 0);
    correlation_valid:out std_logic;
    correlation_re,correlation_im:out signed(ACC_BITS-1 downto 0)
  );
end entity;

architecture rtl of cpm_complex_correlator is
  signal acc_re,acc_im:signed(ACC_BITS-1 downto 0):=(others=>'0');
begin
  process(clk)
    variable ii,qq,qi,iq:signed(2*IQ_BITS-1 downto 0);
    variable re_term,im_term,total_re,total_im:signed(ACC_BITS-1 downto 0);
  begin
    if rising_edge(clk) then
      correlation_valid<='0';
      if reset='1' then
        acc_re<=(others=>'0'); acc_im<=(others=>'0');
        correlation_re<=(others=>'0'); correlation_im<=(others=>'0');
      elsif sample_valid='1' then
        ii:=rx_i*template_i; qq:=rx_q*template_q;
        qi:=rx_q*template_i; iq:=rx_i*template_q;
        re_term:=resize(ii,ACC_BITS)+resize(qq,ACC_BITS);
        im_term:=resize(qi,ACC_BITS)-resize(iq,ACC_BITS);
        if symbol_start='1' then total_re:=re_term; total_im:=im_term;
        else total_re:=acc_re+re_term; total_im:=acc_im+im_term; end if;
        acc_re<=total_re; acc_im<=total_im;
        if symbol_last='1' then
          correlation_re<=total_re; correlation_im<=total_im;
          correlation_valid<='1';
        end if;
      end if;
    end if;
  end process;
end architecture;
