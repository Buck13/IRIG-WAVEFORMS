set src [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [list \
  $src/soqpsk_pulse_pkg.vhd $src/soqpsk_template_pkg.vhd $src/soqpsk_fir.vhd \
  $src/soqpsk_sync_pkg.vhd $src/soqpsk_carrier_nco.vhd $src/soqpsk_carrier_loop.vhd \
  $src/soqpsk_timing_ted.vhd $src/soqpsk_linear_interp.vhd \
  $src/soqpsk_correlation_bank.vhd $src/soqpsk_trellis_scheduler.vhd \
  $src/soqpsk_rx_core.vhd $src/soqpsk_stream_chain.vhd]
synth_design -top soqpsk_stream_chain -part xc7k410t-fbg676-2
report_utilization -file $src/soqpsk_x310_utilization.rpt
report_timing_summary -file $src/soqpsk_x310_timing.rpt
exit
