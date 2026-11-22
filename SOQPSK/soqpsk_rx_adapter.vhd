library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soqpsk_rx_adapter is
  generic (SPS:positive:=8);
  port(clk,reset,enable,restart:in std_logic;
       timing_offset:in unsigned(3 downto 0);
       adc_valid_i,adc_valid_q:in std_logic;
       adc_i,adc_q:in signed(15 downto 0);
       detector_ready:in std_logic;
       sample_valid,symbol_start,symbol_last,aligned,dropped:out std_logic;
       sample_i,sample_q:out signed(15 downto 0);
       symbol_index:out unsigned(7 downto 0));
end entity;

architecture rtl of soqpsk_rx_adapter is
 signal searching:std_logic:='1'; signal raw_pos:unsigned(3 downto 0):=(others=>'0');
 signal phase:natural range 0 to SPS-1:=0; signal index_q:unsigned(7 downto 0):=(others=>'0');
begin
 aligned<=not searching; symbol_index<=index_q;
 process(clk)
   variable selected:boolean;
 begin
  if rising_edge(clk) then
   sample_valid<='0'; symbol_start<='0'; symbol_last<='0'; dropped<='0';
   if reset='1' or restart='1' or enable='0' then
    searching<='1'; raw_pos<=(others=>'0'); phase<=0; index_q<=(others=>'0');
   elsif adc_valid_i='1' and adc_valid_q='1' then
    selected:=false;
    if searching='1' then
     if raw_pos=timing_offset then searching<='0'; phase<=0; selected:=true; end if;
     raw_pos<=raw_pos+1;
    else
     selected:=true;
     if phase=SPS-1 then phase<=0; else phase<=phase+1; end if;
    end if;
    if selected then
     if detector_ready='1' then
      sample_i<=adc_i; sample_q<=adc_q; sample_valid<='1';
      if phase=0 then symbol_start<='1'; end if;
      if phase=SPS-1 then symbol_last<='1'; index_q<=index_q+1; end if;
     else dropped<='1'; end if;
    end if;
   end if;
  end if;
 end process;
end architecture;
