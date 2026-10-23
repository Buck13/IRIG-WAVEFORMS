set root [file dirname [file normalize [info script]]]
set output [file join $root artifacts cpm-h-rx-manual]
file mkdir $output
open_project [file join $root build cpm-h-rx-manual pluto_cpm_h_rx_manual.xpr]
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Manual CPM-H receiver synthesis incomplete"}
open_run synth_1
report_utilization -file [file join $output synthesis-utilization.rpt]
report_timing_summary -delay_type min_max -max_paths 20 -file [file join $output synthesis-timing.rpt]
puts CPM_H_RX_MANUAL_FULL_SYNTHESIS_COMPLETE
exit
