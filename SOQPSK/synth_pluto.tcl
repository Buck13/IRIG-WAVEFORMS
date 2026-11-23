set src [file dirname [file normalize [info script]]]
cd $src
set out pluto_build_nco
file mkdir $out

create_project soqpsk_pluto $out -part xc7z010clg400-1 -force
add_files [list \
  soqpsk_pulse_pkg.vhd soqpsk_template_pkg.vhd soqpsk_template_rom.vhd soqpsk_fir.vhd \
  soqpsk_sync_pkg.vhd soqpsk_carrier_nco.vhd soqpsk_carrier_loop.vhd \
  soqpsk_timing_ted.vhd soqpsk_linear_interp.vhd \
  soqpsk_correlation_bank.vhd soqpsk_trellis_scheduler.vhd soqpsk_survivor_traceback.vhd \
  soqpsk_rx_core.vhd soqpsk_stream_chain.vhd]
set_property file_type {VHDL 2008} [get_files *.vhd]
update_compile_order -fileset sources_1
synth_design -top soqpsk_stream_chain -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file $out/soqpsk_pluto_utilization.rpt
report_timing_summary -file $out/soqpsk_pluto_timing.rpt
exit
