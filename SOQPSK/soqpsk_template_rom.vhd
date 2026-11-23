library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soqpsk_template_pkg.all;

entity soqpsk_template_rom is
  port(clk : in std_logic;
       addr0, addr1 : in unsigned(12 downto 0);
       q0, q1 : out signed(11 downto 0);
       valid : out std_logic);
end entity;

architecture rtl of soqpsk_template_rom is
  type rom_t is array(0 to 8191) of signed(11 downto 0);
  signal rom : rom_t;
  attribute ram_style : string;
  attribute ram_style of rom : signal is "block";
begin
  -- The package remains the golden coefficient source; this registered copy
  -- gives Vivado a synchronous ROM structure to map into BRAM.
  init : process
  begin
    for i in 0 to 8191 loop
      rom(i) <= to_signed(TEMPLATE(i), 12);
    end loop;
    wait;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      q0 <= rom(to_integer(addr0));
      q1 <= rom(to_integer(addr1));
      valid <= '1';
    end if;
  end process;
end architecture;
