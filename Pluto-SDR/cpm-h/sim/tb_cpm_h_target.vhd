library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.cpm_rom_pkg.all;
use work.cpm_h_nco_pkg.all;

entity tb_cpm_h_target is end;
architecture test of tb_cpm_h_target is
  signal clk : std_logic := '0';
  signal reset, ce, valid : std_logic := '0';
  signal dibit : std_logic_vector(1 downto 0) := "00";
  signal rr, rov : std_logic;
  signal rdelta : signed(PHASE_BITS-1 downto 0);
  signal rphase : unsigned(PHASE_BITS-1 downto 0);
  signal pr, pov : std_logic;
  signal pdelta : signed(PHASE_BITS-1 downto 0);
  signal pphase : unsigned(PHASE_BITS-1 downto 0);
  signal tr, tov : std_logic;
  signal ti, tq : signed(15 downto 0);
  function bit_of(n : integer) return std_logic is
  begin
    if n = 0 then return '0'; else return '1'; end if;
  end;
begin
  clk <= not clk after 5 ns;
  reference : entity work.cpm_core
    port map(clk, reset, ce, dibit, valid, rr, rov, rdelta, rphase);
  phase_target : entity work.cpm_h_phase_core
    port map(clk, reset, ce, dibit, valid, pr, pov, pdelta, pphase);
  iq_target : entity work.cpm_h_tx_core
    port map(clk, reset, ce, dibit, valid, tr, tov, ti, tq);

  process
    file vectors : text open read_mode is "vectors.txt";
    variable l : line;
    variable r, c, v, d, ignored : integer;
    type delta_fifo_t is array (0 to 15) of signed(PHASE_BITS-1 downto 0);
    type phase_fifo_t is array (0 to 15) of unsigned(PHASE_BITS-1 downto 0);
    type iq_fifo_t is array (0 to 15) of signed(15 downto 0);
    variable dq : delta_fifo_t; variable pq : phase_fifo_t;
    variable iq : iq_fifo_t; variable qq : iq_fifo_t;
    variable pw, prd, iw, ird : integer range 0 to 15 := 0;
    variable pc, ic : integer range 0 to 16 := 0;
    variable address : integer range 0 to NCO_SIZE-1;
    variable cycle, phase_checked, iq_checked : integer := 0;
  begin
    while not endfile(vectors) loop
      readline(vectors, l);
      read(l,r); read(l,c); read(l,v); read(l,d);
      for n in 1 to 4 loop read(l,ignored); end loop;
      wait until falling_edge(clk);
      reset <= bit_of(r); ce <= bit_of(c); valid <= bit_of(v);
      dibit <= std_logic_vector(to_unsigned(d,2));
      wait for 1 ns;
      assert pr=rr and tr=rr report "ready mismatch at cycle "&integer'image(cycle) severity failure;
      wait until rising_edge(clk); wait for 1 ns;
      if r=1 then
        pc:=0;ic:=0;pw:=0;prd:=0;iw:=0;ird:=0;
      else
        if pov='1' then
          assert pc>0 report "unexpected phase output" severity failure;
          assert pdelta=dq(prd) and pphase=pq(prd) report "pipelined phase mismatch at output "&integer'image(phase_checked) severity failure;
          prd:=(prd+1) mod 16;pc:=pc-1;phase_checked:=phase_checked+1;
        end if;
        if tov='1' then
          assert ic>0 report "unexpected IQ output" severity failure;
          assert ti=iq(ird) and tq=qq(ird) report "I/Q ROM mismatch at output "&integer'image(iq_checked) severity failure;
          ird:=(ird+1) mod 16;ic:=ic-1;iq_checked:=iq_checked+1;
        end if;
        if rov='1' then
          assert pc<16 and ic<16 report "comparison FIFO overflow" severity failure;
          dq(pw):=rdelta;pq(pw):=rphase;pw:=(pw+1) mod 16;pc:=pc+1;
          address:=to_integer(rphase(PHASE_BITS-1 downto PHASE_BITS-NCO_ADDR_BITS));
          iq(iw):=to_signed(SINE_ROM((address+NCO_SIZE/4) mod NCO_SIZE),16);
          qq(iw):=to_signed(SINE_ROM(address),16);
          iw:=(iw+1) mod 16;ic:=ic+1;
        end if;
      end if;
      cycle:=cycle+1;
    end loop;

    -- Drain the target pipelines without advancing waveform time.
    wait until falling_edge(clk); ce<='0';valid<='0';reset<='0';
    for n in 1 to 6 loop
      wait until rising_edge(clk);wait for 1 ns;
      if pov='1' then
        assert pc>0 and pdelta=dq(prd) and pphase=pq(prd) report "phase drain mismatch" severity failure;
        prd:=(prd+1) mod 16;pc:=pc-1;phase_checked:=phase_checked+1;
      end if;
      if tov='1' then
        assert ic>0 and ti=iq(ird) and tq=qq(ird) report "IQ drain mismatch" severity failure;
        ird:=(ird+1) mod 16;ic:=ic-1;iq_checked:=iq_checked+1;
      end if;
    end loop;
    assert pc=0 and ic=0 report "pipelines did not drain" severity failure;
    report "PASS: target phase and IQ equal reference; phase="&integer'image(phase_checked)&" IQ="&integer'image(iq_checked);
    stop;wait;
  end process;
end architecture;
