set root [file dirname [file normalize [info script]]]
set output [file join $root build adapter-synth]
file mkdir $output
cd $output
foreach source {bpsk_mapper pn15_generator pn15_bpsk_tx pluto_pn15_tx_adapter} {
  read_vhdl -vhdl2008 [file join $root vhdl ${source}.vhd]
}
synth_design -top pluto_pn15_tx_adapter -part xc7z010clg400-1 -mode out_of_context
create_clock -name sample_clk -period 10.0 [get_ports clk]
report_utilization -file utilization.rpt
report_timing_summary -file timing.rpt
write_checkpoint -force adapter.dcp
puts "ADAPTER_ZYNQ_SYNTHESIS_COMPLETE"
