-- Four-way banked ping-pong path metrics: two reads per bank per clock.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_receiver_pkg.all;
entity cpm_metric_banks is
  port(
    clk,reset:in std_logic;
    load_valid:in std_logic;load_index:in unsigned(7 downto 0);load_metric:in signed(47 downto 0);
    symbol_start:in std_logic;
    lane0_pred,lane1_pred:in unsigned8_array4_t;
    lane0_old,lane1_old:out signed48_array4_t;
    write_valid:in std_logic;write_dest0,write_dest1:in unsigned(7 downto 0);
    write_metric0,write_metric1:in signed(47 downto 0);
    symbol_end:in std_logic;bank_swapped:out std_logic
  );
end entity;
architecture rtl of cpm_metric_banks is
  type bank_t is array(0 to 63) of signed(47 downto 0);
  signal a0,a1,a2,a3,b0,b1,b2,b3:bank_t;
  signal active:std_logic:='0';signal min_a,min_b:signed(47 downto 0):=(others=>'0');
  signal running_min:signed(47 downto 0):=(47=>'0',others=>'1');
begin
  process(all)
    variable index,address,bank:integer;variable floor:signed(47 downto 0);
  begin
    if active='0' then floor:=min_a;else floor:=min_b;end if;
    for k in 0 to 3 loop
      index:=to_integer(lane0_pred(k));address:=index/4;bank:=index mod 4;
      if active='0' then
        case bank is when 0=>lane0_old(k)<=a0(address)-floor;when 1=>lane0_old(k)<=a1(address)-floor;when 2=>lane0_old(k)<=a2(address)-floor;when others=>lane0_old(k)<=a3(address)-floor;end case;
      else
        case bank is when 0=>lane0_old(k)<=b0(address)-floor;when 1=>lane0_old(k)<=b1(address)-floor;when 2=>lane0_old(k)<=b2(address)-floor;when others=>lane0_old(k)<=b3(address)-floor;end case;
      end if;
      index:=to_integer(lane1_pred(k));address:=index/4;bank:=index mod 4;
      if active='0' then
        case bank is when 0=>lane1_old(k)<=a0(address)-floor;when 1=>lane1_old(k)<=a1(address)-floor;when 2=>lane1_old(k)<=a2(address)-floor;when others=>lane1_old(k)<=a3(address)-floor;end case;
      else
        case bank is when 0=>lane1_old(k)<=b0(address)-floor;when 1=>lane1_old(k)<=b1(address)-floor;when 2=>lane1_old(k)<=b2(address)-floor;when others=>lane1_old(k)<=b3(address)-floor;end case;
      end if;
    end loop;
  end process;
  process(clk)
    variable idx,addr,bank:integer;variable next_min:signed(47 downto 0);
  begin
    if rising_edge(clk) then
      bank_swapped<='0';
      if reset='1' then active<='0';min_a<=(others=>'0');min_b<=(others=>'0');running_min<=(47=>'0',others=>'1');
      else
        if load_valid='1' then
          idx:=to_integer(load_index);addr:=idx/4;bank:=idx mod 4;
          case bank is when 0=>a0(addr)<=load_metric;when 1=>a1(addr)<=load_metric;when 2=>a2(addr)<=load_metric;when others=>a3(addr)<=load_metric;end case;
        end if;
        if symbol_start='1' then running_min<=(47=>'0',others=>'1');end if;
        if write_valid='1' then
          next_min:=running_min;if write_metric0<next_min then next_min:=write_metric0;end if;if write_metric1<next_min then next_min:=write_metric1;end if;
          idx:=to_integer(write_dest0);addr:=idx/4;bank:=idx mod 4;
          if active='0' then case bank is when 0=>b0(addr)<=write_metric0;when 1=>b1(addr)<=write_metric0;when 2=>b2(addr)<=write_metric0;when others=>b3(addr)<=write_metric0;end case;
          else case bank is when 0=>a0(addr)<=write_metric0;when 1=>a1(addr)<=write_metric0;when 2=>a2(addr)<=write_metric0;when others=>a3(addr)<=write_metric0;end case;end if;
          idx:=to_integer(write_dest1);addr:=idx/4;bank:=idx mod 4;
          if active='0' then case bank is when 0=>b0(addr)<=write_metric1;when 1=>b1(addr)<=write_metric1;when 2=>b2(addr)<=write_metric1;when others=>b3(addr)<=write_metric1;end case;
          else case bank is when 0=>a0(addr)<=write_metric1;when 1=>a1(addr)<=write_metric1;when 2=>a2(addr)<=write_metric1;when others=>a3(addr)<=write_metric1;end case;end if;
          running_min<=next_min;
          if symbol_end='1' then
            if active='0' then min_b<=next_min;else min_a<=next_min;end if;
            active<=not active;bank_swapped<='1';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
