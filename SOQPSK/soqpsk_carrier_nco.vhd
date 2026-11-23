library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use work.soqpsk_sync_pkg.all;
entity soqpsk_carrier_nco is port(clk,reset,valid:in std_logic; i_in,q_in:in signed(15 downto 0); phase_word:in unsigned(7 downto 0); i_out,q_out:out signed(31 downto 0); valid_out:out std_logic); end;
architecture rtl of soqpsk_carrier_nco is
  function shift_mult(x:signed(15 downto 0); c:integer) return signed is
    variable acc:signed(31 downto 0):=(others=>'0');
    variable mag:integer;
  begin
    if c<0 then mag:=-c; else mag:=c; end if;
    for b in 0 to 15 loop
      if ((mag / (2**b)) mod 2)=1 then
        acc:=acc+shift_left(resize(x,32),b);
      end if;
    end loop;
    if c<0 then return -acc; else return acc; end if;
  end function;
begin
 process(clk)
   variable p:integer; variable ii,qq,qi,iq:signed(31 downto 0);
 begin
  if rising_edge(clk) then
   valid_out<='0';
   if reset='1' then i_out<=(others=>'0');q_out<=(others=>'0');
   elsif valid='1' then
    p:=to_integer(phase_word(7 downto 3));
    ii:=shift_mult(i_in,COS_Q15(p)); qq:=shift_mult(q_in,COS_Q15(p));
    qi:=shift_mult(q_in,SIN_Q15(p)); iq:=shift_mult(i_in,SIN_Q15(p));
    i_out<=resize(ii,32)+resize(qi,32); q_out<=resize(qq,32)-resize(iq,32); valid_out<='1';
   end if;
  end if;
 end process;
end;
