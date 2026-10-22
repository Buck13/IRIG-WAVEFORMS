library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_receiver_pkg.all;

entity cpm_metric_banks is
  port(
    clk, reset : in std_logic;
    load_valid : in std_logic;
    load_index : in unsigned(7 downto 0);
    load_metric : in signed(47 downto 0);
    symbol_start : in std_logic;
    read_request : in std_logic;
    lane0_pred, lane1_pred : in unsigned8_array4_t;
    read_valid : out std_logic;
    lane0_old, lane1_old : out signed48_array4_t;
    write_valid : in std_logic;
    write_dest0, write_dest1 : in unsigned(7 downto 0);
    write_metric0, write_metric1 : in signed(47 downto 0);
    symbol_end : in std_logic;
    bank_swapped : out std_logic
  );
end entity;

architecture rtl of cpm_metric_banks is
  type metric_ports_t is array(0 to 3) of signed(47 downto 0);
  type addr_ports_t is array(0 to 3) of unsigned(5 downto 0);
  signal active : std_logic := '0';
  signal min_a, min_b : signed(47 downto 0) := (others => '0');
  signal running_min : signed(47 downto 0) := (47 => '0', others => '1');
  signal a_addr0, a_addr1, b_addr0, b_addr1 : addr_ports_t;
  signal a_din0, b_din0 : metric_ports_t;
  signal a_dout0, a_dout1, b_dout0, b_dout1 : metric_ports_t;
  signal a_we0, b_we0 : std_logic_vector(0 to 3);
  signal read_valid_q, read_side_q : std_logic := '0';
begin
  rams : for k in 0 to 3 generate
    ram_a : entity work.cpm_metric_tdp_ram
      port map(clk, a_we0(k), a_addr0(k), a_din0(k), a_dout0(k),
                    a_addr1(k), a_dout1(k));
    ram_b : entity work.cpm_metric_tdp_ram
      port map(clk, b_we0(k), b_addr0(k), b_din0(k), b_dout0(k),
                    b_addr1(k), b_dout1(k));
  end generate;

  process(all)
    variable load_bank, write_bank0, write_bank1 : integer range 0 to 3;
  begin
    for k in 0 to 3 loop
      a_addr0(k) <= lane0_pred(k)(7 downto 2);
      a_addr1(k) <= lane1_pred(k)(7 downto 2);
      b_addr0(k) <= lane0_pred(k)(7 downto 2);
      b_addr1(k) <= lane1_pred(k)(7 downto 2);
      a_din0(k) <= write_metric0;
      b_din0(k) <= write_metric0;
      a_we0(k) <= '0'; b_we0(k) <= '0';
    end loop;

    if load_valid = '1' then
      load_bank := to_integer(load_index(1 downto 0));
      a_addr0(load_bank) <= load_index(7 downto 2);
      a_din0(load_bank) <= load_metric;
      a_we0(load_bank) <= '1';
    end if;

    if write_valid = '1' then
      write_bank0 := to_integer(write_dest0(1 downto 0));
      write_bank1 := to_integer(write_dest1(1 downto 0));
      if active = '0' then
        b_addr0(write_bank0) <= write_dest0(7 downto 2);
        b_din0(write_bank0) <= write_metric0;
        b_we0(write_bank0) <= '1';
        b_addr0(write_bank1) <= write_dest1(7 downto 2);
        b_din0(write_bank1) <= write_metric1;
        b_we0(write_bank1) <= '1';
      else
        a_addr0(write_bank0) <= write_dest0(7 downto 2);
        a_din0(write_bank0) <= write_metric0;
        a_we0(write_bank0) <= '1';
        a_addr0(write_bank1) <= write_dest1(7 downto 2);
        a_din0(write_bank1) <= write_metric1;
        a_we0(write_bank1) <= '1';
      end if;
    end if;
  end process;

  read_valid <= read_valid_q;
  process(all)
    variable floor : signed(47 downto 0);
  begin
    if read_side_q = '0' then
      floor := min_a;
      for k in 0 to 3 loop
        lane0_old(k) <= a_dout0(k) - floor;
        lane1_old(k) <= a_dout1(k) - floor;
      end loop;
    else
      floor := min_b;
      for k in 0 to 3 loop
        lane0_old(k) <= b_dout0(k) - floor;
        lane1_old(k) <= b_dout1(k) - floor;
      end loop;
    end if;
  end process;

  process(clk)
    variable next_min : signed(47 downto 0);
  begin
    if rising_edge(clk) then
      bank_swapped <= '0';
      read_valid_q <= read_request;
      if read_request = '1' then read_side_q <= active; end if;
      if reset = '1' then
        active <= '0'; min_a <= (others => '0'); min_b <= (others => '0');
        running_min <= (47 => '0', others => '1'); read_valid_q <= '0'; read_side_q <= '0';
      else
        if symbol_start = '1' then running_min <= (47 => '0', others => '1'); end if;
        if write_valid = '1' then
          next_min := running_min;
          if write_metric0 < next_min then next_min := write_metric0; end if;
          if write_metric1 < next_min then next_min := write_metric1; end if;
          running_min <= next_min;
          if symbol_end = '1' then
            if active = '0' then min_b <= next_min; else min_a <= next_min; end if;
            active <= not active; bank_swapped <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
