library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_cpm_viterbi_engine is end;
architecture test of tb_cpm_viterbi_engine is
  signal clk : std_logic := '0';
  signal reset, ready, busy, cwv, start, sv, done : std_logic := '0';
  signal cwi : unsigned(5 downto 0) := (others => '0');
  signal cwr, cwiq : signed(17 downto 0) := (others => '0');
  signal epoch : unsigned(1 downto 0) := (others => '0');
  signal d0, d1 : unsigned(7 downto 0);
  signal s0, s1 : unsigned(1 downto 0);
  signal m0, m1 : signed(47 downto 0);
begin
  clk <= not clk after 5 ns;
  dut : entity work.cpm_viterbi_engine
    port map(clk,reset,ready,busy,cwv,cwi,cwr,cwiq,start,epoch,sv,d0,d1,s0,s1,m0,m1,done);

  process
    file vectors : text open read_mode is "viterbi_engine_vectors.txt";
    variable l : line;
    variable ed0, es0, em0, ed1, es1, em1, count : integer := 0;
  begin
    reset <= '1'; wait until rising_edge(clk); reset <= '0';
    for i in 0 to 63 loop
      wait until falling_edge(clk); cwv <= '1'; cwi <= to_unsigned(i,6);
      cwr <= to_signed(((i*37) mod 1000)-500,18);
      cwiq <= to_signed(((i*53) mod 1000)-500,18);
      wait until rising_edge(clk);
    end loop;
    wait until falling_edge(clk); cwv <= '0';
    while ready /= '1' loop wait until rising_edge(clk); end loop;
    wait until falling_edge(clk); start <= '1'; epoch <= "00";
    wait until rising_edge(clk); wait until falling_edge(clk); start <= '0';
    while count < 128 loop
      wait until rising_edge(clk); wait for 1 ns;
      if sv = '1' then
        readline(vectors,l); read(l,ed0); read(l,es0); read(l,em0);
        read(l,ed1); read(l,es1); read(l,em1);
        assert to_integer(d0)=ed0 and to_integer(d1)=ed1 report "destination mismatch" severity failure;
        assert to_integer(s0)=es0 and to_integer(s1)=es1 report "survivor mismatch" severity failure;
        assert to_integer(m0)=em0 and to_integer(m1)=em1 report "metric mismatch" severity failure;
        count := count + 1;
      end if;
    end loop;
    while done /= '1' loop wait until rising_edge(clk); wait for 1 ns; end loop;
    assert done='1' and ready='1' and busy='0' report "completion handshake mismatch" severity failure;
    report "PASS: 128 integrated two-lane Viterbi writes" severity note;
    stop; wait;
  end process;
end architecture;
