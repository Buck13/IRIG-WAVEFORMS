set root [file dirname [file normalize [info script]]]
open_checkpoint [file join $root build pn15 pluto_pn15.runs impl_1 system_top_postroute_physopt.dcp]
source [file join $root audit-pn15-cdc.tcl]
read_xdc [file join $root hdl projects pluto dma_metadata_cdc.xdc]
read_xdc [file join $root pn15_control_cdc.xdc]
report_timing_summary -report_unconstrained -file [file join $root logs pn15-cdc-check.rpt]
report_timing -slack_lesser_than 0 -max_paths 20 -file [file join $root logs pn15-cdc-failures.rpt]
puts "PN15_CDC_CHECK_DONE"
