library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use std.env.all;
entity pluto_tx_top_tb is end;
architecture test of pluto_tx_top_tb is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal control : std_logic_vector(0 downto 0) := "0";
  signal ei, eq, request : std_logic := '0';
  signal ti, tq : std_logic_vector(15 downto 0);
begin
  clk <= not clk after 5 ns;
  dut : entity work.pluto_pn15_tx_top
    port map (clk, reset, control, ei, eq, request, x"1234", x"5678", ti, tq);
  process
    file vectors : text open read_mode is "pn15_default.mem";
    variable ln : line;
    variable b : bit;
    variable expected, held : std_logic_vector(15 downto 0);
    procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
  begin
    tick; reset <= '0'; tick;
    assert ti = x"1234" and tq = x"5678" report "Default DMA bypass failed" severity failure;
    wait for 2 ns; control <= "1"; ei <= '1'; eq <= '1';
    tick;
    assert ti = x"1234" report "Control bypassed synchroniser" severity failure;
    tick; tick; tick; -- synchronisation and source priming
    for symbol in 0 to 63 loop
      readline(vectors, ln); read(ln, b);
      if b = '1' then expected := x"4000"; else expected := x"C000"; end if;
      for sample in 0 to 7 loop
        request <= '0'; held := ti; tick;
        assert ti = held report "Unrequested sample advance" severity failure;
        request <= '1'; tick;
        assert ti = expected and tq = x"0000" report "Integrated source sequence mismatch" severity failure;
      end loop;
    end loop;
    eq <= '0'; tick;
    assert ti = x"0000" and tq = x"0000" report "Unpaired channel did not mute" severity failure;
    request <= '0'; control <= "0"; tick; tick; tick;
    assert ti = x"1234" and tq = x"5678" report "Return to DMA failed" severity failure;
    control <= "1"; eq <= '1'; tick; tick; tick; tick;
    request <= '1'; tick;
    assert ti = x"4000" and tq = x"0000" report "Reselect did not restart seed" severity failure;
    reset <= '1'; tick;
    assert ti = x"1234" and tq = x"5678" report "Reset did not select DMA" severity failure;
    report "PASS: PLUTO TX TOP CONTROL CDC, SEQUENCE, CHANNEL GATING AND BYPASS";
    finish;
  end process;
end architecture;
