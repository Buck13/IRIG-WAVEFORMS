library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_schedule_pkg.all;

entity cpm_survivor_traceback is
  generic(TRACEBACK_DEPTH : positive := 32);
  port(
    clk, reset : in std_logic;
    survivor_valid : in std_logic;
    destination0, destination1 : in unsigned(7 downto 0);
    survivor0, survivor1 : in unsigned(1 downto 0);
    metric0, metric1 : in signed(47 downto 0);
    symbol_done : in std_logic;
    symbol_epoch : in unsigned(1 downto 0);
    decoded_valid : out std_logic;
    decoded_dibit : out unsigned(1 downto 0);
    traceback_busy : out std_logic
  );
end entity;

architecture rtl of cpm_survivor_traceback is
  constant ROW_WORDS : positive := 128;
  constant MEMORY_WORDS : positive := TRACEBACK_DEPTH * ROW_WORDS;
  type survivor_ram_t is array(0 to MEMORY_WORDS-1) of unsigned(1 downto 0);
  type epoch_ram_t is array(0 to TRACEBACK_DEPTH-1) of unsigned(1 downto 0);
  signal even_ram, odd_ram : survivor_ram_t;
  signal epoch_ram : epoch_ram_t;
  attribute ram_style : string;
  attribute ram_style of even_ram : signal is "block";
  attribute ram_style of odd_ram : signal is "block";

  signal write_row : integer range 0 to TRACEBACK_DEPTH-1 := 0;
  signal history_count : integer range 0 to TRACEBACK_DEPTH := 0;
  signal best_metric : signed(47 downto 0) := (others => '0');
  signal best_state : unsigned(7 downto 0) := (others => '0');
  signal read_address : integer range 0 to MEMORY_WORDS-1 := 0;
  signal read_bank : std_logic := '0';
  signal even_read, odd_read : unsigned(1 downto 0);
  signal traceback_state : unsigned(7 downto 0) := (others => '0');
  signal traceback_row : integer range 0 to TRACEBACK_DEPTH-1 := 0;
  signal traceback_step : integer range 0 to TRACEBACK_DEPTH-1 := 0;
  signal active, consume : std_logic := '0';
begin
  traceback_busy <= active;

  process(clk)
    variable address0, address1 : integer range 0 to MEMORY_WORDS-1;
  begin
    if rising_edge(clk) then
      if survivor_valid='1' then
        address0 := write_row*ROW_WORDS + to_integer(destination0(7 downto 1));
        address1 := write_row*ROW_WORDS + to_integer(destination1(7 downto 1));
        assert destination0(0)='0' and destination1(0)='1'
          report "survivor lanes must be even then odd" severity failure;
        even_ram(address0)<=survivor0;
        odd_ram(address1)<=survivor1;
      end if;
      even_read <= even_ram(read_address);
      odd_read <= odd_ram(read_address);
    end if;
  end process;

  process(clk)
    variable choice : unsigned(1 downto 0);
    variable rom_address : integer range 0 to SCHEDULE_WORDS-1;
    variable next_row : integer range 0 to TRACEBACK_DEPTH-1;
    variable next_best_metric : signed(47 downto 0);
    variable next_best_state : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      decoded_valid <= '0';
      if reset='1' then
        write_row<=0; history_count<=0; best_metric<=(others=>'0'); best_state<=(others=>'0');
        active<='0'; consume<='0'; traceback_step<=0; traceback_row<=0;
      else
        if survivor_valid='1' then
          next_best_metric:=best_metric;next_best_state:=best_state;
          if destination0=0 then
            next_best_metric:=metric0;next_best_state:=destination0;
            if metric1<next_best_metric then next_best_metric:=metric1;next_best_state:=destination1;end if;
          else
            if metric0<next_best_metric then next_best_metric:=metric0;next_best_state:=destination0;end if;
            if metric1<next_best_metric then next_best_metric:=metric1;next_best_state:=destination1;end if;
          end if;
          best_metric<=next_best_metric;best_state<=next_best_state;
        end if;

        if symbol_done='1' then
          epoch_ram(write_row)<=symbol_epoch;
          if history_count=TRACEBACK_DEPTH-1 or history_count=TRACEBACK_DEPTH then
            active<='1'; consume<='0'; traceback_state<=best_state;
            traceback_row<=write_row; traceback_step<=0;
            read_address<=write_row*ROW_WORDS+to_integer(best_state(7 downto 1));
            read_bank<=best_state(0);
          end if;
          if history_count<TRACEBACK_DEPTH then history_count<=history_count+1;end if;
          if write_row=TRACEBACK_DEPTH-1 then write_row<=0;else write_row<=write_row+1;end if;
        end if;

        if active='1' then
          if consume='0' then
            consume<='1';
          else
            if read_bank='0' then choice:=even_read;else choice:=odd_read;end if;
            if traceback_step=TRACEBACK_DEPTH-1 then
              decoded_dibit<=traceback_state(3 downto 2);decoded_valid<='1';active<='0';consume<='0';
            else
              rom_address:=to_integer(epoch_ram(traceback_row))*1024+to_integer(traceback_state)*4+to_integer(choice);
              traceback_state<=to_unsigned(PRED_ROM(rom_address),8);
              if traceback_row=0 then next_row:=TRACEBACK_DEPTH-1;else next_row:=traceback_row-1;end if;
              traceback_row<=next_row;traceback_step<=traceback_step+1;consume<='0';
              read_address<=next_row*ROW_WORDS+PRED_ROM(rom_address)/2;
              if (PRED_ROM(rom_address) mod 2)=0 then read_bank<='0';else read_bank<='1';end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
