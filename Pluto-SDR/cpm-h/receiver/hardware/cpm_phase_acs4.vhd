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
  type product_array_t is array(0 to 3) of signed(33 downto 0);
  type candidate_array_t is array(0 to 3) of signed(48 downto 0);
  signal product_re, product_im : product_array_t;
  signal old_metric_q : signed48_array4_t;
  signal candidate_q : candidate_array_t;
  signal pair_metric0, pair_metric1 : signed(48 downto 0);
  signal pair_survivor0, pair_survivor1 : unsigned(1 downto 0);
  signal valid1, valid2, valid3 : std_logic := '0';
begin
  process(clk)
    variable score:signed(48 downto 0);
    variable best:signed(48 downto 0);
    variable win:integer range 0 to 3;
    variable p:integer range 0 to 31;
  begin
    if rising_edge(clk) then
      output_valid <= valid3;
      if reset='1' then
        best_metric<=(others=>'0'); survivor<=(others=>'0');
        valid1<='0'; valid2<='0'; valid3<='0'; output_valid<='0';
      else
        if valid3='1' then
          if pair_metric0 <= pair_metric1 then
            best_metric<=resize(pair_metric0,48); survivor<=pair_survivor0;
          else
            best_metric<=resize(pair_metric1,48); survivor<=pair_survivor1;
          end if;
        end if;
        valid3 <= valid2;
        if valid2='1' then
          if candidate_q(0) <= candidate_q(1) then
            pair_metric0<=candidate_q(0); pair_survivor0<="00";
          else
            pair_metric0<=candidate_q(1); pair_survivor0<="01";
          end if;
          if candidate_q(2) <= candidate_q(3) then
            pair_metric1<=candidate_q(2); pair_survivor1<="10";
          else
            pair_metric1<=candidate_q(3); pair_survivor1<="11";
          end if;
        end if;
        valid2 <= valid1;
        if valid1='1' then
          for k in 0 to 3 loop
            score:=shift_right(resize(product_re(k),49)+resize(product_im(k),49),15);
            candidate_q(k)<=resize(old_metric_q(k),49)-score;
          end loop;
        end if;
        valid1 <= input_valid;
        if input_valid='1' then
          old_metric_q <= old_metric;
          for k in 0 to 3 loop
            p:=to_integer(phase_index(k));
            product_re(k)<=correlation_re(k)*to_signed(COS_Q15(p),16);
            product_im(k)<=correlation_im(k)*to_signed(SIN_Q15(p),16);
          end loop;
        end if;
      end if;
    end if;
  end process;
end architecture;
