-- Two destination jobs per clock for the 256-state steady CPM trellis.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_schedule_pkg.all;
entity cpm_state_scheduler is
  port(
    clk,reset,start:in std_logic;
    epoch:in unsigned(1 downto 0);
    job_valid:out std_logic;
    destination0,destination1:out unsigned(7 downto 0);
    pred0,pred1,pred2,pred3:out unsigned(7 downto 0);
    corr0,corr1,corr2,corr3:out unsigned(5 downto 0);
    phase0,phase1,phase2,phase3:out unsigned(4 downto 0);
    lane1_pred0,lane1_pred1,lane1_pred2,lane1_pred3:out unsigned(7 downto 0);
    lane1_corr0,lane1_corr1,lane1_corr2,lane1_corr3:out unsigned(5 downto 0);
    lane1_phase0,lane1_phase1,lane1_phase2,lane1_phase3:out unsigned(4 downto 0);
    done:out std_logic
  );
end entity;
architecture rtl of cpm_state_scheduler is
  signal running:std_logic:='0';signal cycle:integer range 0 to 127:=0;
begin
  process(clk)
    variable base0,base1:integer range 0 to 4095;
  begin
    if rising_edge(clk) then
      job_valid<='0';done<='0';
      if reset='1' then
        running<='0'; cycle<=0;
        destination0<=(others=>'0'); destination1<=(others=>'0');
        pred0<=(others=>'0'); pred1<=(others=>'0'); pred2<=(others=>'0'); pred3<=(others=>'0');
        corr0<=(others=>'0'); corr1<=(others=>'0'); corr2<=(others=>'0'); corr3<=(others=>'0');
        phase0<=(others=>'0'); phase1<=(others=>'0'); phase2<=(others=>'0'); phase3<=(others=>'0');
        lane1_pred0<=(others=>'0'); lane1_pred1<=(others=>'0'); lane1_pred2<=(others=>'0'); lane1_pred3<=(others=>'0');
        lane1_corr0<=(others=>'0'); lane1_corr1<=(others=>'0'); lane1_corr2<=(others=>'0'); lane1_corr3<=(others=>'0');
        lane1_phase0<=(others=>'0'); lane1_phase1<=(others=>'0'); lane1_phase2<=(others=>'0'); lane1_phase3<=(others=>'0');
      elsif start='1' and running='0' then running<='1';cycle<=0;
      elsif running='1' then
        base0:=to_integer(epoch)*1024+(2*cycle)*4;
        base1:=base0+4;
        destination0<=to_unsigned(2*cycle,8);destination1<=to_unsigned(2*cycle+1,8);
        pred0<=to_unsigned(PRED_ROM(base0),8);pred1<=to_unsigned(PRED_ROM(base0+1),8);pred2<=to_unsigned(PRED_ROM(base0+2),8);pred3<=to_unsigned(PRED_ROM(base0+3),8);
        corr0<=to_unsigned(CORR_ROM(base0),6);corr1<=to_unsigned(CORR_ROM(base0+1),6);corr2<=to_unsigned(CORR_ROM(base0+2),6);corr3<=to_unsigned(CORR_ROM(base0+3),6);
        phase0<=to_unsigned(PHASE_ROM(base0),5);phase1<=to_unsigned(PHASE_ROM(base0+1),5);phase2<=to_unsigned(PHASE_ROM(base0+2),5);phase3<=to_unsigned(PHASE_ROM(base0+3),5);
        lane1_pred0<=to_unsigned(PRED_ROM(base1),8);lane1_pred1<=to_unsigned(PRED_ROM(base1+1),8);lane1_pred2<=to_unsigned(PRED_ROM(base1+2),8);lane1_pred3<=to_unsigned(PRED_ROM(base1+3),8);
        lane1_corr0<=to_unsigned(CORR_ROM(base1),6);lane1_corr1<=to_unsigned(CORR_ROM(base1+1),6);lane1_corr2<=to_unsigned(CORR_ROM(base1+2),6);lane1_corr3<=to_unsigned(CORR_ROM(base1+3),6);
        lane1_phase0<=to_unsigned(PHASE_ROM(base1),5);lane1_phase1<=to_unsigned(PHASE_ROM(base1+1),5);lane1_phase2<=to_unsigned(PHASE_ROM(base1+2),5);lane1_phase3<=to_unsigned(PHASE_ROM(base1+3),5);
        job_valid<='1';
        if cycle=127 then running<='0';done<='1';else cycle<=cycle+1;end if;
      end if;
    end if;
  end process;
end architecture;
