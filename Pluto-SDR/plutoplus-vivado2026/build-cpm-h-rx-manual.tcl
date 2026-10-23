set root [file dirname [file normalize [info script]]]
set output [file join $root artifacts cpm-h-rx-manual]
file mkdir $output
open_project [file join $root build cpm-h-rx-manual pluto_cpm_h_rx_manual.xpr]

set clock_xdc [file join $root cpm-h-rx-clock-groups.xdc]
if {![llength [get_files -quiet $clock_xdc]]} {
  add_files -fileset constrs_1 -norecurse $clock_xdc
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Manual CPM-H receiver implementation failed"
}
open_run impl_1
set timing [report_timing_summary -report_unconstrained -return_string \
  -file [file join $output timing.rpt]]
if {![string match "*All user specified timing constraints are met.*" $timing] ||
    [string match "*VIOLATED*" $timing]} {
  error "Manual CPM-H receiver timing check failed; no validated artifact exported"
}
foreach delay_type {max min} {
  if {[llength [get_timing_paths -quiet -delay_type $delay_type \
      -slack_lesser_than 0 -max_paths 1]]} {
    error "Negative $delay_type timing path remains"
  }
}
report_drc -file [file join $output drc.rpt]
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {
  error "Manual CPM-H receiver DRC errors remain"
}
report_utilization -file [file join $output utilization.rpt]
report_utilization -hierarchical -hierarchical_depth 8 \
  -file [file join $output utilization-hierarchical.rpt]
report_cdc -details -file [file join $output cdc.rpt]
write_checkpoint -force [file join $output pluto_cpm_h_rx_manual.dcp]
write_bitstream -force -bin_file [file join $output pluto_cpm_h_rx_manual.bit]
write_hw_platform -fixed -include_bit -force \
  -file [file join $output pluto_cpm_h_rx_manual.xsa]
puts CPM_H_RX_MANUAL_TIMING_CHECKED_AND_EXPORTED
exit
