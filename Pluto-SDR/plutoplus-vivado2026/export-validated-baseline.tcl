set root [file dirname [file normalize [info script]]]
set board [file join $root hdl projects pluto]
set output [file join $root artifacts baseline]
file mkdir $output
open_project [file join $board pluto.xpr]
open_run impl_1
source [file join $board dma_metadata_cdc.xdc]
set summary [report_timing_summary -report_unconstrained -return_string -file [file join $output timing.rpt]]
if {![string match "*All user specified timing constraints are met.*" $summary] || [string match "*VIOLATED*" $summary]} {
  error "Full timing check failed; no validated artifact exported."
}
foreach delay_type {max min} {
  if {[llength [get_timing_paths -quiet -delay_type $delay_type -slack_lesser_than 0 -max_paths 1]]} {
    error "Negative $delay_type timing path remains."
  }
}
report_drc -file [file join $output drc.rpt]
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {
  error "DRC errors remain."
}
report_methodology -file [file join $output methodology.rpt]
report_cdc -details -file [file join $output cdc.rpt]
report_utilization -file [file join $output utilization.rpt]
report_exceptions -coverage -file [file join $output exceptions.rpt]
write_checkpoint -force [file join $output pluto_baseline.dcp]
write_bitstream -force -bin_file [file join $output pluto_baseline.bit]
write_hw_platform -fixed -include_bit -force -file [file join $output pluto_baseline.xsa]
puts "VALIDATED_BASELINE_EXPORTED"
