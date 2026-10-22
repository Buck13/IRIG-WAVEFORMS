-- Four-predecessor phase scoring and add-compare-select for one CPM destination.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_receiver_pkg.all;
entity cpm_phase_acs4 is
  port(
    clk,reset,input_valid:in std_logic;
    old_metric:in signed48_array4_t;
    correlation_re,correlation_im:in signed18_array4_t;
    phase_index:in phase_array4_t;
    output_valid:out std_logic;
    best_metric:out signed(47 downto 0);
    survivor:out unsigned(1 downto 0)
  );
end entity;
architecture rtl of cpm_phase_acs4 is
begin
  process(clk)
    variable cre_cos,cim_sin:signed(33 downto 0);
    variable score:signed(48 downto 0);
    variable candidate,best:signed(48 downto 0);
    variable win:integer range 0 to 3;
    variable p:integer range 0 to 31;
  begin
    if rising_edge(clk) then
      output_valid<='0';
      if reset='1' then best_metric<=(others=>'0');survivor<=(others=>'0');
      elsif input_valid='1' then
        best:=(others=>'0');win:=0;
        for k in 0 to 3 loop
          p:=to_integer(phase_index(k));
          cre_cos:=correlation_re(k)*to_signed(COS_Q15(p),16);
          cim_sin:=correlation_im(k)*to_signed(SIN_Q15(p),16);
          score:=shift_right(resize(cre_cos,49)+resize(cim_sin,49),15);
          candidate:=resize(old_metric(k),49)-score;
          if k=0 or candidate<best then best:=candidate;win:=k;end if;
        end loop;
        best_metric<=resize(best,48);survivor<=to_unsigned(win,2);output_valid<='1';
      end if;
    end if;
  end process;
end architecture;
