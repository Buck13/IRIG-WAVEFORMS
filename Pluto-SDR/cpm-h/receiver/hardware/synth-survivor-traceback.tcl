set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root cpm_schedule_pkg.vhd]
read_vhdl -vhdl2008 [file join $root cpm_survivor_traceback.vhd]
synth_design -top cpm_survivor_traceback -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root .. results survivor-traceback-synthesis-utilization.rpt]
report_timing_summary -delay_type min_max -max_paths 10 -file [file join $root .. results survivor-traceback-synthesis-timing.rpt]
puts CPM_SURVIVOR_TRACEBACK_SYNTHESIS_COMPLETE
exit
