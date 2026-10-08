library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- Clock-synchronous source, prefetch FIFO bridges core latency to util_upack timing.
entity pluto_pcm_fm_adapter is
 generic(SAMPLES_PER_SYMBOL : positive := 8);
 port(clk, reset, select_pcm, enable, restart : in std_logic;
      seed : in std_logic_vector(14 downto 0);
      sample_request : in std_logic;
      dma_i, dma_q : in std_logic_vector(15 downto 0);
      tx_i, tx_q : out std_logic_vector(15 downto 0);
      sample_valid, primed, underflow : out std_logic);
end;
architecture rtl of pluto_pcm_fm_adapter is
 constant DEPTH : integer := 32;
 type fifo_t is array(0 to DEPTH-1) of std_logic_vector(31 downto 0);
 signal fifo : fifo_t;
 signal wr, rd : integer range 0 to DEPTH-1 := 0;
 signal filled, reserved : integer range 0 to DEPTH := 0;
 signal armed, fault : std_logic := '0';
 signal lfsr : std_logic_vector(14 downto 0) := (others=>'1');
 signal bit_count : integer range 0 to SAMPLES_PER_SYMBOL-1 := 0;
 signal nrz : signed(1 downto 0);
 signal clear, issue, consume, core_valid : std_logic;
 signal ci,cq : signed(15 downto 0);
 signal sample : std_logic_vector(31 downto 0) := (others=>'0');
begin
 clear <= reset or restart or not select_pcm or not enable;
 issue <= '1' when clear='0' and reserved<DEPTH else '0';
 consume <= '1' when clear='0' and armed='1' and sample_request='1' and filled>0 else '0';
 nrz <= to_signed(1,2) when lfsr(0)='1' else to_signed(-1,2);
 core: entity work.pcm_fm_core port map(clk=>clk,reset=>clear,sample_ce=>issue,
  nrz_in=>nrz,i_out=>ci,q_out=>cq,out_valid=>core_valid,phase_debug=>open);
 tx_i <= dma_i when select_pcm='0' else sample(31 downto 16);
 tx_q <= dma_q when select_pcm='0' else sample(15 downto 0);
 primed <= armed; underflow <= fault;
 process(clk)
 begin
  if rising_edge(clk) then
   sample_valid <= '0';
   if clear='1' then
    wr<=0; rd<=0; filled<=0; reserved<=0; armed<='0'; fault<='0';
    bit_count<=0; sample<=(others=>'0');
    if unsigned(seed)=0 then lfsr<=(others=>'1'); else lfsr<=seed; end if;
   else
    if issue='1' then
     if bit_count=SAMPLES_PER_SYMBOL-1 then
      bit_count<=0; lfsr<=(lfsr(14) xor lfsr(0)) & lfsr(14 downto 1);
     else bit_count<=bit_count+1; end if;
    end if;
    -- reserved counts both queued samples and all core samples in flight.
    if issue='1' and consume='0' then reserved<=reserved+1;
    elsif issue='0' and consume='1' then reserved<=reserved-1; end if;
    if core_valid='1' then
     assert filled<DEPTH or consume='1' report "PCM FIFO overflow" severity failure;
     fifo(wr)<=std_logic_vector(ci)&std_logic_vector(cq); wr<=(wr+1) mod DEPTH;
    end if;
    if core_valid='1' and consume='0' then filled<=filled+1;
    elsif core_valid='0' and consume='1' then filled<=filled-1; end if;
    if filled>=16 then armed<='1'; end if;
    if consume='1' then
     sample<=fifo(rd); rd<=(rd+1) mod DEPTH; sample_valid<='1';
    elsif sample_request='1' then
     sample<=(others=>'0');
     if armed='1' then fault<='1'; end if;
    end if;
   end if;
  end if;
 end process;
end;
