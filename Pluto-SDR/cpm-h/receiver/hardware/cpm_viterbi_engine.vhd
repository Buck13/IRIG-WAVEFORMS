library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpm_receiver_pkg.all;

entity cpm_viterbi_engine is
  generic(INIT_METRIC : signed(47 downto 0) := to_signed(16777216, 48));
  port(
    clk, reset : in std_logic;
    ready, busy : out std_logic;
    correlation_write_valid : in std_logic;
    correlation_write_index : in unsigned(5 downto 0);
    correlation_write_re, correlation_write_im : in signed(17 downto 0);
    start : in std_logic;
    epoch : in unsigned(1 downto 0);
    survivor_valid : out std_logic;
    survivor_destination0, survivor_destination1 : out unsigned(7 downto 0);
    survivor_choice0, survivor_choice1 : out unsigned(1 downto 0);
    survivor_metric0, survivor_metric1 : out signed(47 downto 0);
    done : out std_logic
  );
end entity;

architecture rtl of cpm_viterbi_engine is
  type correlation_ram_t is array(0 to 63) of signed(17 downto 0);
  type corr_addr_array_t is array(0 to 3) of unsigned(5 downto 0);
  signal correlation_re_ram, correlation_im_ram : correlation_ram_t;
  attribute ram_style : string;
  attribute ram_style of correlation_re_ram : signal is "distributed";
  attribute ram_style of correlation_im_ram : signal is "distributed";
  signal initializing : std_logic := '1';
  signal init_index : unsigned(7 downto 0) := (others => '0');
  signal running : std_logic := '0';

  signal scheduler_start, job_valid, scheduler_done : std_logic := '0';
  signal destination0, destination1 : unsigned(7 downto 0);
  signal pred0, pred1, pred2, pred3 : unsigned(7 downto 0);
  signal lane1_pred0, lane1_pred1, lane1_pred2, lane1_pred3 : unsigned(7 downto 0);
  signal corr0, corr1, corr2, corr3 : unsigned(5 downto 0);
  signal lane1_corr0, lane1_corr1, lane1_corr2, lane1_corr3 : unsigned(5 downto 0);
  signal phase0, phase1, phase2, phase3 : unsigned(4 downto 0);
  signal lane1_phase0, lane1_phase1, lane1_phase2, lane1_phase3 : unsigned(4 downto 0);
  signal lane0_pred, lane1_pred : unsigned8_array4_t;
  signal lane0_phase, lane1_phase : phase_array4_t;
  signal lane0_corr_addr, lane1_corr_addr : corr_addr_array_t := (others => (others => '0'));
  signal lane0_corr_re, lane0_corr_im, lane1_corr_re, lane1_corr_im : signed18_array4_t;
  signal acs0_old_q, acs1_old_q : signed48_array4_t;
  signal acs0_corr_re_q, acs0_corr_im_q, acs1_corr_re_q, acs1_corr_im_q : signed18_array4_t;
  signal acs0_phase_q, acs1_phase_q : phase_array4_t;
  signal acs_input_valid : std_logic := '0';

  signal read_valid, acs0_valid, acs1_valid, bank_swapped : std_logic;
  signal lane0_old, lane1_old : signed48_array4_t;
  signal best_metric0, best_metric1 : signed(47 downto 0);
  signal best_survivor0, best_survivor1 : unsigned(1 downto 0);
  signal read_destination0, read_destination1 : unsigned(7 downto 0);
  type destination_pipe_t is array(0 to 4) of unsigned(7 downto 0);
  signal destination0_pipe, destination1_pipe : destination_pipe_t;
  signal read_last : std_logic := '0';
  signal last_pipe : std_logic_vector(0 to 4) := (others => '0');
  signal load_metric : signed(47 downto 0);
begin
  ready <= not initializing and not running;
  busy <= initializing or running;
  load_metric <= (others => '0') when init_index = 0 else INIT_METRIC;

  scheduler : entity work.cpm_state_scheduler
    port map(clk, reset, scheduler_start, epoch, job_valid, destination0, destination1,
      pred0, pred1, pred2, pred3, corr0, corr1, corr2, corr3,
      phase0, phase1, phase2, phase3,
      lane1_pred0, lane1_pred1, lane1_pred2, lane1_pred3,
      lane1_corr0, lane1_corr1, lane1_corr2, lane1_corr3,
      lane1_phase0, lane1_phase1, lane1_phase2, lane1_phase3, scheduler_done);

  lane0_pred <= (pred0, pred1, pred2, pred3);
  lane1_pred <= (lane1_pred0, lane1_pred1, lane1_pred2, lane1_pred3);
  process(all)
  begin
    for k in 0 to 3 loop
      lane0_corr_re(k) <= correlation_re_ram(to_integer(lane0_corr_addr(k)));
      lane0_corr_im(k) <= correlation_im_ram(to_integer(lane0_corr_addr(k)));
      lane1_corr_re(k) <= correlation_re_ram(to_integer(lane1_corr_addr(k)));
      lane1_corr_im(k) <= correlation_im_ram(to_integer(lane1_corr_addr(k)));
    end loop;
  end process;

  metrics : entity work.cpm_metric_banks
    port map(clk, reset, initializing, init_index, load_metric,
      scheduler_start, job_valid, lane0_pred, lane1_pred, read_valid,
      lane0_old, lane1_old, acs0_valid and acs1_valid,
      destination0_pipe(4), destination1_pipe(4), best_metric0, best_metric1,
      last_pipe(4), bank_swapped);

  acs_lane0 : entity work.cpm_phase_acs4
    port map(clk, reset, acs_input_valid, acs0_old_q, acs0_corr_re_q, acs0_corr_im_q,
      acs0_phase_q, acs0_valid, best_metric0, best_survivor0);
  acs_lane1 : entity work.cpm_phase_acs4
    port map(clk, reset, acs_input_valid, acs1_old_q, acs1_corr_re_q, acs1_corr_im_q,
      acs1_phase_q, acs1_valid, best_metric1, best_survivor1);

  survivor_valid <= acs0_valid and acs1_valid;
  survivor_destination0 <= destination0_pipe(4);
  survivor_destination1 <= destination1_pipe(4);
  survivor_choice0 <= best_survivor0;
  survivor_choice1 <= best_survivor1;
  survivor_metric0 <= best_metric0;
  survivor_metric1 <= best_metric1;

  process(clk)
  begin
    if rising_edge(clk) then
      scheduler_start <= '0';
      done <= '0';
      if reset = '1' then
        initializing <= '1'; init_index <= (others => '0'); running <= '0';
        read_last <= '0'; last_pipe <= (others => '0'); acs_input_valid <= '0';
      else
        if correlation_write_valid = '1' then
          correlation_re_ram(to_integer(correlation_write_index)) <= correlation_write_re;
          correlation_im_ram(to_integer(correlation_write_index)) <= correlation_write_im;
        end if;
        if initializing = '1' then
          if init_index = 255 then initializing <= '0';
          else init_index <= init_index + 1; end if;
        elsif start = '1' and running = '0' then
          scheduler_start <= '1'; running <= '1';
        end if;

        if job_valid = '1' then
          read_destination0 <= destination0; read_destination1 <= destination1;
          lane0_phase <= (phase0, phase1, phase2, phase3);
          lane1_phase <= (lane1_phase0, lane1_phase1, lane1_phase2, lane1_phase3);
          lane0_corr_addr <= (corr0, corr1, corr2, corr3);
          lane1_corr_addr <= (lane1_corr0, lane1_corr1, lane1_corr2, lane1_corr3);
          read_last <= scheduler_done;
        end if;
        acs_input_valid <= read_valid;
        if read_valid = '1' then
          destination0_pipe(0) <= read_destination0; destination1_pipe(0) <= read_destination1;
          last_pipe(0) <= read_last;
          acs0_old_q <= lane0_old; acs1_old_q <= lane1_old;
          acs0_corr_re_q <= lane0_corr_re; acs0_corr_im_q <= lane0_corr_im;
          acs1_corr_re_q <= lane1_corr_re; acs1_corr_im_q <= lane1_corr_im;
          acs0_phase_q <= lane0_phase; acs1_phase_q <= lane1_phase;
        end if;
        for k in 1 to 4 loop
          destination0_pipe(k) <= destination0_pipe(k-1);
          destination1_pipe(k) <= destination1_pipe(k-1);
          last_pipe(k) <= last_pipe(k-1);
        end loop;
        if bank_swapped = '1' then
          running <= '0'; done <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
