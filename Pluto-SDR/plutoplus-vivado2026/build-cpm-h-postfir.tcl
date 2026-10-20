set root [file dirname [file normalize [info script]]]
set output [file join $root artifacts cpm-h-postfir]
file mkdir $output
open_project [file join $root build cpm-h-postfir pluto_cpm_h.xpr]
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "CPM-H synthesis incomplete"}
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $root audit-pn15-cdc.tcl] [get_runs impl_1]
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "CPM-H implementation failed"}
open_run impl_1
source [file join $root audit-pn15-cdc.tcl]
set summary [report_timing_summary -report_unconstrained -return_string -file [file join $output timing.rpt]]
if {![string match "*All user specified timing constraints are met.*" $summary] || [string match "*VIOLATED*" $summary]} {error "CPM-H full timing check failed; no validated artifact exported"}
foreach delay_type {max min} {
  if {[llength [get_timing_paths -quiet -delay_type $delay_type -slack_lesser_than 0 -max_paths 1]]} {error "Negative $delay_type timing path remains"}
}
report_drc -file [file join $output drc.rpt]
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "CPM-H DRC errors remain"}
report_utilization -file [file join $output utilization.rpt]
report_utilization -hierarchical -hierarchical_depth 6 -file [file join $output utilization-hierarchical.rpt]
report_cdc -details -file [file join $output cdc.rpt]
report_methodology -file [file join $output methodology.rpt]
report_exceptions -coverage -file [file join $output exceptions.rpt]
write_checkpoint -force [file join $output pluto_cpm_h.dcp]
write_bitstream -force -bin_file [file join $output pluto_cpm_h.bit]
write_hw_platform -fixed -include_bit -force -file [file join $output pluto_cpm_h.xsa]
puts CPM_H_BUILD_TIMING_CHECKED_AND_EXPORTED
