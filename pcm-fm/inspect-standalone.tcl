set root [file dirname [file normalize [info script]]]
open_checkpoint [file join $root build standalone routed.dcp]
report_timing -delay_type min -from [all_registers -clock core_clk] -to [all_registers -clock core_clk] -max_paths 10 -file [file join $root build standalone internal-hold.rpt]
report_timing -delay_type max -from [all_registers -clock core_clk] -to [all_registers -clock core_clk] -max_paths 10 -file [file join $root build standalone internal-setup.rpt]
set bad [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 10000 -nworst 1]
set from_port 0
set internal 0
foreach p $bad {
 set start [get_property STARTPOINT_PIN $p]
 if {[llength [get_ports -quiet $start]]} {incr from_port} else {incr internal}
}
puts "HOLD_CLASSIFICATION input_port=$from_port other=$internal"
