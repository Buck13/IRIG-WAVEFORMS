library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_cpm_rx_observation_adapter is end;
architecture sim of tb_cpm_rx_observation_adapter is
  signal clk:std_logic:='0';
  signal reset,enable,restart,vi,vq,ready,ov,first,aligned,dropped:std_logic:='0';
  signal offset:unsigned(4 downto 0):=to_unsigned(5,5);
  signal start_epoch,epoch:unsigned(1 downto 0):="10";
  signal ai,aq:std_logic_vector(15 downto 0):=(others=>'0');
  signal oi,oq:signed(11 downto 0);
begin
  clk<=not clk after 5 ns;
  dut:entity work.cpm_rx_observation_adapter
    port map(clk,reset,enable,restart,offset,start_epoch,vi,vq,ai,aq,ready,
      ov,first,oi,oq,epoch,aligned,dropped);
  process
    variable accepted,raw:integer:=0;
  begin
    reset<='1'; wait for 25 ns; wait until falling_edge(clk);
    reset<='0';enable<='1';ready<='1';
    -- ADC samples arrive alternately 6 and 7 clocks apart (16 MS/s into 100 MHz).
    while accepted<34 loop
      for gap in 1 to 5+(raw mod 2) loop wait until falling_edge(clk); end loop;
      ai<=std_logic_vector(to_signed(raw,16));
      aq<=std_logic_vector(to_signed(-raw,16));vi<='1';vq<='1';
      wait until falling_edge(clk);vi<='0';vq<='0';raw:=raw+1;
      if ov='1' then
        assert to_integer(oi)=5+2*accepted report "selected I sample mismatch got="&integer'image(to_integer(oi))&" expected="&integer'image(5+2*accepted) severity failure;
        assert to_integer(oq)=-(5+2*accepted) report "selected Q sample mismatch" severity failure;
        if accepted=0 or accepted=16 or accepted=32 then
          assert first='1' report "symbol_start missing" severity failure;
        else assert first='0' report "unexpected symbol_start" severity failure; end if;
        if accepted=0 then assert epoch="10" report "first epoch mismatch" severity failure;
        elsif accepted=16 then assert epoch="11" report "second epoch mismatch" severity failure;
        elsif accepted=32 then assert epoch="00" report "epoch wrap mismatch" severity failure; end if;
        accepted:=accepted+1;
      end if;
    end loop;
    assert aligned='1' and dropped='0' report "adapter status failure" severity failure;
    report "PASS: manual timing selected 34 observations across epoch wrap" severity note;
    stop;wait;
  end process;
end architecture;
