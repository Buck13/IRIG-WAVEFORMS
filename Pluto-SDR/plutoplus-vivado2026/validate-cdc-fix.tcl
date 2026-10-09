set root [file dirname [file normalize [info script]]]
open_checkpoint [file join $root hdl projects pluto pluto.runs impl_1 system_top_postroute_physopt.dcp]
source [file join $root hdl projects pluto dma_metadata_cdc.xdc]
report_timing_summary -report_unconstrained -file timing_cdc_fixed.rpt
report_timing -slack_lesser_than 0 -max_paths 30 -file remaining_failures.rpt
report_exceptions -coverage -file exceptions_cdc_fixed.rpt
