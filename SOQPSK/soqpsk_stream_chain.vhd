library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- Fixed-point streaming composition for one SOQPSK receive channel.
entity soqpsk_stream_chain is
 port(clk,reset,valid_in:in std_logic; adc_i,adc_q:in signed(15 downto 0);
      ready_out,bit_valid,bit_out:out std_logic; llr:out signed(7 downto 0));
end entity;
architecture rtl of soqpsk_stream_chain is
 signal fi_v,fq_v,nco_v,int_v:std_logic; signal fi,fq:signed(31 downto 0); signal ni,nq,ii,iq:signed(31 downto 0); signal ph:unsigned(7 downto 0); signal ce:signed(31 downto 0); signal te:signed(31 downto 0); signal tick:std_logic;
begin
 fir_i:entity work.soqpsk_fir port map(clk,reset,valid_in,adc_i,fi_v,fi);
 fir_q:entity work.soqpsk_fir port map(clk,reset,valid_in,adc_q,fq_v,fq);
 loop0:entity work.soqpsk_carrier_loop port map(clk,reset,fi_v,ni,nq,ph,ce);
 nco:entity work.soqpsk_carrier_nco port map(clk,reset,fi_v,fi(31 downto 16),fq(31 downto 16),ph,ni,nq,nco_v);
 ted:entity work.soqpsk_timing_ted port map(clk,reset,nco_v,ni,nq,tick,te);
 intp:entity work.soqpsk_linear_interp port map(clk,reset,nco_v,to_unsigned(128,8),ni,nq,ii,iq,int_v);
 core:entity work.soqpsk_rx_core port map(clk,reset,int_v,'0','0',ii(31 downto 16),ready_out,bit_valid,bit_out,llr);
end architecture;
