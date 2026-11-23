library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Circular survivor memory for the 256-state SOQPSK trellis.
-- One predecessor bit is stored per destination state and symbol row.
entity soqpsk_survivor_traceback is
  generic(DEPTH:positive:=32);
  port(clk,reset:in std_logic;
       survivor_valid:in std_logic;
       survivor_state:in unsigned(7 downto 0);
       survivor_prev:in unsigned(7 downto 7);
       symbol_done:in std_logic;
       best_state:in unsigned(7 downto 0);
       decoded_valid:out std_logic;
       decoded_bit:out std_logic;
       busy:out std_logic);
end entity;

architecture rtl of soqpsk_survivor_traceback is
  constant WORDS:positive:=DEPTH*256;
  type ram_t is array(0 to WORDS-1) of std_logic;
  signal ram:ram_t;
  attribute ram_style:string;
  attribute ram_style of ram:signal is "block";
  signal row:integer range 0 to DEPTH-1:=0;
  signal count:integer range 0 to DEPTH:=0;
  signal active:std_logic:='0';
  signal trace_row:integer range 0 to DEPTH-1:=0;
  signal trace_state:unsigned(7 downto 0):=(others=>'0');
  signal step:integer range 0 to DEPTH-1:=0;
begin
  busy<=active;
  process(clk)
    variable addr:integer;
    variable predecessor:unsigned(7 downto 0);
    variable next_row:integer;
  begin
    if rising_edge(clk) then
      decoded_valid<='0';
      if reset='1' then
        row<=0; count<=0; active<='0'; trace_row<=0; trace_state<=(others=>'0'); step<=0;
      else
        if survivor_valid='1' then
          addr:=row*256+to_integer(survivor_state);
          ram(addr)<=survivor_prev(7);
        end if;
        if symbol_done='1' and active='0' then
          if count<DEPTH then count<=count+1; end if;
          if row=DEPTH-1 then next_row:=0; else next_row:=row+1; end if;
          row<=next_row;
          if count>=DEPTH-1 then
            active<='1'; trace_row<=row; trace_state<=best_state; step<=0;
          end if;
        elsif active='1' then
          predecessor(7):=ram(trace_row*256+to_integer(trace_state));
          predecessor(6 downto 0):=trace_state(7 downto 1);
          if step=DEPTH-1 then
            decoded_bit<=trace_state(0); decoded_valid<='1'; active<='0';
          else
            trace_state<=predecessor;
            if trace_row=0 then trace_row<=DEPTH-1; else trace_row<=trace_row-1; end if;
            step<=step+1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
