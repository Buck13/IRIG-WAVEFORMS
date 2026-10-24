library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Self-synchronizing PN15 quality check.  The first 15 decoded bits establish
-- the unknown LFSR phase; the next 64 bits are checked against
-- b[n+15] = b[n+14] xor b[n].
entity cpm_pn15_quality is
  port(
    clk,reset:in std_logic;
    decoded_valid:in std_logic;
    decoded_dibit:in unsigned(1 downto 0);
    done:out std_logic;
    errors:out unsigned(6 downto 0);
    checked:out unsigned(6 downto 0)
  );
end entity;

architecture rtl of cpm_pn15_quality is
  signal history:std_logic_vector(14 downto 0):=(others=>'0');
  signal learned_count:natural range 0 to 15:=0;
  signal checked_count:natural range 0 to 64:=0;
  signal error_count:unsigned(6 downto 0):=(others=>'0');
  signal done_q:std_logic:='0';
begin
  done<=done_q;
  errors<=error_count;
  checked<=to_unsigned(checked_count,7);

  process(clk)
    variable h:std_logic_vector(14 downto 0);
    variable learned:natural range 0 to 15;
    variable count:natural range 0 to 64;
    variable faults:unsigned(6 downto 0);
    variable bit_value,predicted:std_logic;
    variable finished:std_logic;
  begin
    if rising_edge(clk) then
      if reset='1' then
        history<=(others=>'0');learned_count<=0;checked_count<=0;
        error_count<=(others=>'0');done_q<='0';
      elsif decoded_valid='1' and done_q='0' then
        h:=history;learned:=learned_count;count:=checked_count;
        faults:=error_count;finished:='0';
        for position in 1 downto 0 loop
          if finished='0' then
            bit_value:=decoded_dibit(position);
            if learned<15 then
              h(learned):=bit_value;
              learned:=learned+1;
              if learned=15 and h=(h'range=>'0') then
                faults:=to_unsigned(64,7);count:=64;finished:='1';
              end if;
            else
              predicted:=h(14) xor h(0);
              if bit_value/=predicted then faults:=faults+1;end if;
              h:=bit_value & h(14 downto 1);
              if count=63 then count:=64;finished:='1';
              else count:=count+1;end if;
            end if;
          end if;
        end loop;
        history<=h;learned_count<=learned;checked_count<=count;
        error_count<=faults;done_q<=finished;
      end if;
    end if;
  end process;
end architecture;
