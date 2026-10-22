set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root cpm_receiver_pkg.vhd]
read_vhdl -vhdl2008 [file join $root cpm_phase_acs4.vhd]
synth_design -top cpm_phase_acs4 -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root .. results phase-acs-synthesis-utilization.rpt]
report_timing_summary -file [file join $root .. results phase-acs-synthesis-timing.rpt]
puts CPM_PHASE_ACS_SYNTHESIS_COMPLETE
exit
