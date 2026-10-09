library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcm_fm_tables.all;

-- Atomic Python sample mapped into an 11-clock latency pipeline.
-- Accepts one +/-1 NRZ sample each clock when sample_ce=1; no output backpressure.
entity pcm_fm_core is
  port(clk, reset, sample_ce : in std_logic;
       nrz_in : in signed(1 downto 0);
       i_out, q_out : out signed(15 downto 0);
       out_valid : out std_logic;
       phase_debug : out unsigned(31 downto 0));
end entity;
architecture rtl of pcm_fm_core is
  type history_t is array(0 to 63) of signed(1 downto 0);
  signal history : history_t := (others => (others => '0'));
  type sums_t is array(0 to 127) of signed(20 downto 0);
  type tree_t is array(0 to 7) of sums_t;
  signal tree : tree_t := (others => (others => (others => '0')));
  signal valid_pipe : std_logic_vector(0 to 10) := (others => '0');
  signal product : signed(49 downto 0) := (others => '0');
  signal increment : signed(31 downto 0) := (others => '0');
  signal phase : unsigned(31 downto 0) := (others => '0');
  function tap(x : signed(1 downto 0); c : integer) return signed is
  begin
    if x = to_signed(1,2) then return to_signed(c,21);
    elsif x = to_signed(-1,2) then return to_signed(-c,21);
    else return to_signed(0,21); end if;
  end function;
begin
  process(clk)
    variable magnitude, rounded : signed(49 downto 0);
    variable address : integer range 0 to 4095;
  begin
    if rising_edge(clk) then
      if reset='1' then
        history <= (others => (others => '0'));
        tree <= (others => (others => (others => '0')));
        valid_pipe <= (others => '0');
        product <= (others => '0'); increment <= (others => '0');
        phase <= (others => '0'); phase_debug <= (others => '0');
        i_out <= to_signed(16384,16); q_out <= (others => '0'); out_valid <= '0';
      else
        valid_pipe(0) <= sample_ce;
        for level in 1 to 10 loop valid_pipe(level) <= valid_pipe(level-1); end loop;
        out_valid <= valid_pipe(10);
        if sample_ce='1' then
          assert nrz_in=to_signed(1,2) or nrz_in=to_signed(-1,2)
            report "NRZ input must be +/-1" severity failure;
          history(0) <= nrz_in;
          for k in 1 to 63 loop history(k) <= history(k-1); end loop;
          tree(0)(0) <= tap(nrz_in,COEFF(0));
          for k in 1 to 64 loop tree(0)(k) <= tap(history(k-1),COEFF(k)); end loop;
          for k in 65 to 127 loop tree(0)(k) <= (others => '0'); end loop;
        end if;
        for level in 1 to 7 loop
          if valid_pipe(level-1)='1' then
            for k in 0 to 2**(7-level)-1 loop
              tree(level)(k) <= tree(level-1)(2*k)+tree(level-1)(2*k+1);
            end loop;
          end if;
        end loop;
        if valid_pipe(7)='1' then
          product <= tree(7)(0) * to_signed(187904819,29);
        end if;
        if valid_pipe(8)='1' then
          if product<0 then magnitude := -product; else magnitude := product; end if;
          rounded := shift_right(magnitude + to_signed(65536,50),17);
          if product<0 then increment <= resize(-rounded,32);
          else increment <= resize(rounded,32); end if;
        end if;
        if valid_pipe(9)='1' then phase <= phase + unsigned(increment); end if;
        if valid_pipe(10)='1' then
          address := to_integer(phase(31 downto 20));
          q_out <= to_signed(SINE(address),16);
          i_out <= to_signed(SINE((address+1024) mod 4096),16);
          phase_debug <= phase;
        end if;
      end if;
    end if;
  end process;
end architecture;
