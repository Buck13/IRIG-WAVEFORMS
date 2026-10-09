library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity pluto_adapter_tb is end;
architecture test of pluto_adapter_tb is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal select_pn, enable, restart, request, valid : std_logic := '0';
  signal tx_i, tx_q : std_logic_vector(15 downto 0);
  signal seed : std_logic_vector(14 downto 0) := (others => '1');
begin
  clk <= not clk after 5 ns;
  dut : entity work.pluto_pn15_tx_adapter
    generic map (SAMPLES_PER_SYMBOL => 8)
    port map (clk, reset, select_pn, enable, restart, seed, request,
              x"1234", x"5678", tx_i, tx_q, valid);
  process
    file vectors : text open read_mode is "pn15_default.mem";
    variable ln : line;
    variable b : bit;
    variable expected : std_logic_vector(15 downto 0);
    variable held : std_logic_vector(15 downto 0);
    procedure tick is
    begin wait until rising_edge(clk); wait for 1 ns; end;
  begin
    tick;
    assert tx_i = x"1234" and tx_q = x"5678" report "DMA bypass changed" severity failure;
    reset <= '0'; select_pn <= '1'; enable <= '1';
    tick; -- Prime the streaming source before the first request.
    for symbol in 0 to 32766 loop
      readline(vectors, ln); read(ln, b);
      if b = '1' then expected := x"4000"; else expected := x"C000"; end if;
      for sample in 0 to 7 loop
        request <= '0'; held := tx_i;
        for gap in 0 to (symbol + sample) mod 3 loop
          tick;
          assert valid = '0' and tx_i = held report "Sample changed without request" severity failure;
        end loop;
        request <= '1'; tick;
        assert valid = '1' and tx_i = expected and tx_q = x"0000"
          report "PN sample or request latency mismatch" severity failure;
      end loop;
    end loop;
    -- The sequence wraps to the first bit after one complete period.
    tick;
    assert tx_i = x"4000" and valid = '1' report "Period wrap failed" severity failure;
    enable <= '0'; tick;
    assert tx_i = x"0000" and tx_q = x"0000" and valid = '0' report "Disable failed" severity failure;
    enable <= '1'; restart <= '1'; tick;
    assert tx_i = x"0000" and valid = '0' report "Restart failed" severity failure;
    restart <= '0'; request <= '0'; tick;
    request <= '1'; tick;
    assert tx_i = x"4000" and valid = '1' report "Restart seed failed" severity failure;
    select_pn <= '0'; tick;
    assert tx_i = x"1234" and tx_q = x"5678" report "Return to DMA failed" severity failure;
    report "PASS: PLUTO ADAPTER FULL PN15 PERIOD, GAPS, BYPASS, DISABLE AND RESTART";
    finish;
  end process;
end architecture;
