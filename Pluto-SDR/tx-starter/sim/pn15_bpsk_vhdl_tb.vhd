-- Tests use the independent Python bit-recurrence reference files.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity pn15_vhdl_checker is
  generic (SPS : positive := 8);
  port (done : out std_logic := '0');
end entity;

architecture test of pn15_vhdl_checker is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal enable, restart, ready : std_logic := '0';
  signal seed : std_logic_vector(14 downto 0) := (others => '1');
  signal data : std_logic_vector(31 downto 0);
  signal valid : std_logic;
  type bit_array is array(0 to 32766) of integer range 0 to 1;
  impure function load_bits(filename : string) return bit_array is
    file input_file : text open read_mode is filename;
    variable line_buf : line;
    variable result : bit_array;
  begin
    for n in result'range loop
      readline(input_file, line_buf);
      read(line_buf, result(n));
    end loop;
    return result;
  end function;
  constant ref_default : bit_array := load_bits("pn15_default.mem");
  constant ref_alternate : bit_array := load_bits("pn15_alternate.mem");
begin
  clk <= not clk after 5 ns;
  dut : entity work.pn15_bpsk_tx
    generic map (SAMPLES_PER_SYMBOL => SPS)
    port map (clk, reset, enable, restart, seed, data, valid, ready);

  stimulus : process
    variable accepted, total : natural := 0;
    variable alternate, was_stalled : boolean := false;
    variable held_data : std_logic_vector(31 downto 0);
    variable random_seed1 : positive := 217;
    variable random_seed2 : positive := 913;
    variable random_value : real;
    variable next_enable, next_ready : std_logic;

    procedure cycle(e, r : std_logic) is
      variable expected_bit : integer;
      variable expected_word : std_logic_vector(31 downto 0);
      variable index : natural;
    begin
      wait until falling_edge(clk);
      enable <= e;
      ready <= r;
      wait until rising_edge(clk);
      if was_stalled then
        assert valid = '1' and data = held_data
          report "Data/valid changed during stall" severity failure;
      end if;
      if valid = '1' and ready = '1' then
        index := (accepted / SPS) mod 32767;
        if alternate then expected_bit := ref_alternate(index);
        else expected_bit := ref_default(index); end if;
        if expected_bit = 1 then expected_word := x"40000000";
        else expected_word := x"C0000000"; end if;
        assert data = expected_word
          report "PN/BPSK mismatch at accepted sample " & integer'image(accepted)
          severity failure;
        accepted := accepted + 1;
        total := total + 1;
      end if;
      was_stalled := valid = '1' and ready = '0';
      held_data := data;
      wait for 1 ns;
    end procedure;

    procedure load_seed(value : natural; other : boolean) is
    begin
      wait until falling_edge(clk);
      seed <= std_logic_vector(to_unsigned(value, 15));
      restart <= '1';
      wait until rising_edge(clk);
      wait for 1 ns;
      assert valid = '0' report "Restart did not clear valid" severity failure;
      accepted := 0;
      alternate := other;
      was_stalled := false;
      wait until falling_edge(clk);
      restart <= '0';
    end procedure;

    procedure random_cycle(pause_enable : boolean) is
    begin
      uniform(random_seed1, random_seed2, random_value);
      if pause_enable and random_value < 0.1 then next_enable := '0';
      else next_enable := '1'; end if;
      uniform(random_seed1, random_seed2, random_value);
      if random_value < 0.25 then next_ready := '0';
      else next_ready := '1'; end if;
      cycle(next_enable, next_ready);
    end procedure;
  begin
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    reset <= '0';
    while accepted < (32767+32)*SPS loop random_cycle(true); end loop;
    cycle('1', '0');
    for n in 1 to 20 loop cycle('0', '0'); end loop;
    for n in 1 to 4 loop cycle('0', '1'); end loop;
    assert valid = '0' report "Disable failed to drain output" severity failure;
    cycle('1', '0');
    load_seed(16#1234#, true);
    while accepted < (32767+32)*SPS loop random_cycle(false); end loop;
    load_seed(0, false);
    while accepted < 64*SPS loop cycle('1', '1'); end loop;
    report "PASS: VHDL PN15 BPSK, SPS=" & integer'image(SPS) &
           ", accepted samples=" & integer'image(total);
    done <= '1';
    wait;
  end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity pn15_bpsk_vhdl_tb is end entity;
architecture test of pn15_bpsk_vhdl_tb is
  signal done1, done8 : std_logic;
begin
  one : entity work.pn15_vhdl_checker generic map (1) port map (done1);
  eight : entity work.pn15_vhdl_checker generic map (8) port map (done8);
  process
  begin
    wait until done1 = '1' and done8 = '1';
    report "PASS: ALL VHDL TX TESTS";
    finish;
  end process;
  process
  begin
    wait for 20 ms;
    assert false report "Simulation timeout" severity failure;
  end process;
end architecture;
