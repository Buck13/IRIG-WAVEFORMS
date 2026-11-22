library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Resource-bounded 256-state SOQPSK ACS scheduler.
-- One state is presented to the correlation bank per clock; the bank returns
-- two branch metrics for bit 0/1. Metrics are maximized (correlation score).
entity soqpsk_trellis_scheduler is
  generic (METRIC_BITS:positive:=40);
  port(clk,reset,start,metric_valid:in std_logic;
       metric0,metric1:in signed(METRIC_BITS-1 downto 0);
       state_index:out unsigned(7 downto 0); busy,symbol_done:out std_logic;
       decoded_bit:out std_logic; llr:out signed(7 downto 0));
end entity;

architecture rtl of soqpsk_trellis_scheduler is
  type metric_array is array(0 to 255) of signed(METRIC_BITS-1 downto 0);
  signal pm,npm:metric_array := (others=>(others=>'0'));
  signal state_q:integer range 0 to 255:=0; signal busy_q:std_logic:='0';
begin
  busy<=busy_q; state_index<=to_unsigned(state_q,8);
  process(clk)
    variable s,ns0,ns1:integer; variable a0,a1:signed(METRIC_BITS-1 downto 0);
    variable best0,best1:signed(METRIC_BITS-1 downto 0); variable li:integer;
  begin
    if rising_edge(clk) then
      symbol_done<='0';
      if reset='1' then
        busy_q<='0'; state_q<=0; pm<=(0=>(others=>'0'),others=>(others=>'1')); npm<=(others=>(others=>'1')); llr<=(others=>'0'); decoded_bit<='0';
      elsif start='1' and busy_q='0' then
        busy_q<='1'; state_q<=0; npm<=(others=>(others=>'1'));
      elsif busy_q='1' and metric_valid='1' then
        s:=state_q; ns0:=(s*2) mod 256; ns1:=(s*2+1) mod 256;
        a0:=pm(s)+metric0; a1:=pm(s)+metric1;
        if a0>npm(ns0) then npm(ns0)<=a0; end if;
        if a1>npm(ns1) then npm(ns1)<=a1; end if;
        if state_q=255 then
          pm<=npm; busy_q<='0'; symbol_done<='1';
          best0:=npm(0); best1:=npm(1);
          if best1>best0 then decoded_bit<='1'; else decoded_bit<='0'; end if;
          li:=to_integer(best0-best1); if li>127 then li:=127; elsif li < -128 then li:=-128; end if; llr<=to_signed(li,8);
        else state_q<=state_q+1; end if;
      end if;
    end if;
  end process;
end architecture;
