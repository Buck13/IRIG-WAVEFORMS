set root [file dirname [file normalize [info script]]]
set output [file join $root build standalone]
file mkdir $output
cd $output
read_vhdl -vhdl2008 [file join $root hdl pcm_fm_tables.vhd]
read_vhdl -vhdl2008 [file join $root hdl pcm_fm_core.vhd]
read_xdc [file join $root standalone.xdc]
synth_design -top pcm_fm_core -part xc7z010clg400-1 -mode out_of_context
report_utilization -file synthesis-utilization.rpt
report_timing_summary -file synthesis-timing.rpt
write_checkpoint -force synthesized.dcp
opt_design
place_design
phys_opt_design
route_design
report_utilization -file routed-utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed-timing.rpt
report_drc -file routed-drc.rpt
write_checkpoint -force routed.dcp
puts "PCM_FM_STANDALONE_COMPLETE"
