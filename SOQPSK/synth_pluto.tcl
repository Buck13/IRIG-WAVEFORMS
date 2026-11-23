set src [file dirname [file normalize [info script]]]
cd $src
set out pluto_build
file mkdir $out

read_vhdl -vhdl2008 [list \
  soqpsk_pulse_pkg.vhd soqpsk_template_pkg.vhd soqpsk_fir.vhd \
  soqpsk_sync_pkg.vhd soqpsk_carrier_nco.vhd soqpsk_carrier_loop.vhd \
  soqpsk_timing_ted.vhd soqpsk_linear_interp.vhd \
  soqpsk_correlation_bank.vhd soqpsk_trellis_scheduler.vhd \
  soqpsk_rx_core.vhd soqpsk_stream_chain.vhd]
synth_design -top soqpsk_stream_chain -part xc7z010clg400-1
report_utilization -file $out/soqpsk_pluto_utilization.rpt
report_timing_summary -file $out/soqpsk_pluto_timing.rpt
exit
