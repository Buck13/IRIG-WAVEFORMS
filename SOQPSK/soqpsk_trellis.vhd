library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soqpsk_trellis is
  generic (OBS_BITS : positive := 12; METRIC_BITS : positive := 24; AMP : integer := 256);
  port (clk, reset, valid : in std_logic;
        observation : in signed(OBS_BITS-1 downto 0);
        bit_valid, bit_out : out std_logic;
        llr : out signed(7 downto 0));
end entity;

architecture rtl of soqpsk_trellis is
  type metric_array is array(0 to 3) of signed(METRIC_BITS-1 downto 0);
  signal pm : metric_array := (others => (others=>'0'));
  signal started : std_logic := '0';
begin
  process(clk)
    variable next_pm : metric_array;
    variable old_pm, score, best0, best1 : integer;
    variable e : integer;
    variable obs : integer;
    variable llr_i : integer;
  begin
    if rising_edge(clk) then
      bit_valid <= '0';
      if reset='1' then
        pm <= (0 => (others=>'0'), others => (others=>'1'));
        started <= '0'; llr <= (others=>'0'); bit_out <= '0';
      elsif valid='1' then
        obs := to_integer(observation); best0 := -2**30; best1 := -2**30;
        for n in 0 to 3 loop next_pm(n) := to_signed(-2**30, METRIC_BITS); end loop;
        for s in 0 to 3 loop
          old_pm := to_integer(pm(s));
          for b in 0 to 1 loop
            if b=0 then e:=0; else if (s mod 2)=0 then e:=AMP; else e:=-AMP; end if; end if;
            score := old_pm + 2*obs*e - e*e;
            if b=0 and score>best0 then best0:=score; end if;
            if b=1 and score>best1 then best1:=score; end if;
            if score > to_integer(next_pm(((s*2)+b) mod 4)) then next_pm(((s*2)+b) mod 4):=to_signed(score,METRIC_BITS); end if;
          end loop;
        end loop;
        pm <= next_pm; llr_i:=best0-best1;
        if llr_i>127 then llr_i:=127; elsif llr_i < -128 then llr_i:=-128; end if;
        llr <= to_signed(llr_i,8); bit_out <= '1' when best1>best0 else '0'; bit_valid<='1';
      end if;
    end if;
  end process;
end architecture;
