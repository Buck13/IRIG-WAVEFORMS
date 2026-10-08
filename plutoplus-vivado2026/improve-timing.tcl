# Retry implementation using the existing successful synthesis checkpoint.
set root [file dirname [file normalize [info script]]]
cd [file join $root hdl projects pluto]
open_project pluto.xpr
if {![llength [get_files -quiet *dma_metadata_cdc.xdc]]} {
  add_files -fileset constrs_1 -norecurse dma_metadata_cdc.xdc
}
set_property USED_IN_SYNTHESIS false [get_files *dma_metadata_cdc.xdc]
set_property PROCESSING_ORDER LATE [get_files *dma_metadata_cdc.xdc]
reset_run impl_1
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveFanoutOpt [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Implementation did not complete: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
set timing [report_timing_summary -file timing_improved.log -return_string]
if {[string match "*VIOLATED*" $timing] || [string match "*Timing constraints are not met*" $timing]} {
  error "Timing still fails. Bitstream is not approved for device testing."
}
file mkdir pluto.sdk
write_hw_platform -fixed -include_bit -force -file pluto.sdk/system_top.xsa
puts "BASELINE_TIMING_PASS_AND_XSA_EXPORTED"
