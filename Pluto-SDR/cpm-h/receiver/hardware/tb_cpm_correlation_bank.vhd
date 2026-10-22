library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_cpm_correlation_bank is end;
architecture sim of tb_cpm_correlation_bank is
  signal clk : std_logic := '0';
  signal reset,sample_valid,symbol_start,parity : std_logic := '0';
  signal sample_ready,result_valid,result_last,overflow : std_logic;
  signal rx_i,rx_q : signed(11 downto 0) := (others=>'0');
  signal result_index : unsigned(5 downto 0);
  signal result_re,result_im : signed(17 downto 0);
begin
  clk<=not clk after 5 ns;
  dut: entity work.cpm_correlation_bank
    port map(clk,reset,sample_valid,sample_ready,symbol_start,parity,rx_i,rx_q,
      result_valid,result_index,result_re,result_im,result_last,overflow);

  process
    file f:text open read_mode is "correlation_bank_vectors.txt";
    variable l:line; variable tag:string(1 to 4);
    variable p,iv,qv,idx,erv,eiv:integer;
  begin
    reset<='1'; wait for 25 ns; wait until rising_edge(clk); reset<='0';
    for testcase in 0 to 1 loop
      readline(f,l); read(l,tag); read(l,p); parity<=std_logic'val(p+2);
      for n in 0 to 15 loop
        readline(f,l); read(l,tag(1)); read(l,iv); read(l,qv);
        wait until rising_edge(clk) and sample_ready='1';
        rx_i<=to_signed(iv,12); rx_q<=to_signed(qv,12);
        if n=0 then symbol_start<='1'; else symbol_start<='0'; end if;
        sample_valid<='1'; wait until rising_edge(clk); sample_valid<='0'; symbol_start<='0';
      end loop;
      for n in 0 to 63 loop
        readline(f,l); read(l,tag(1)); read(l,idx); read(l,erv); read(l,eiv);
        wait until rising_edge(clk) and result_valid='1';
        assert to_integer(result_index)=idx report "correlation index mismatch" severity failure;
        assert to_integer(result_re)=erv report "real correlation mismatch at index "&integer'image(idx) severity failure;
        assert to_integer(result_im)=eiv report "imag correlation mismatch at index "&integer'image(idx) severity failure;
        if n=63 then assert result_last='1' report "missing result_last" severity failure; end if;
      end loop;
      assert overflow='0' report "result buffer overflow" severity failure;
    end loop;
    report "CPM correlation bank passed 128 correlations" severity note;
    stop; wait;
  end process;
end architecture;
