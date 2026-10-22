set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root cpm_receiver_pkg.vhd]
read_vhdl -vhdl2008 [file join $root cpm_schedule_pkg.vhd]
read_vhdl -vhdl2008 [file join $root cpm_state_scheduler.vhd]
read_vhdl -vhdl2008 [file join $root cpm_metric_tdp_ram.vhd]
read_vhdl -vhdl2008 [file join $root cpm_metric_banks.vhd]
read_vhdl -vhdl2008 [file join $root cpm_phase_acs4.vhd]
read_vhdl -vhdl2008 [file join $root cpm_viterbi_engine.vhd]
synth_design -top cpm_viterbi_engine -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root .. results viterbi-engine-synthesis-utilization.rpt]
report_timing_summary -delay_type min_max -max_paths 10 -file [file join $root .. results viterbi-engine-synthesis-timing.rpt]
puts CPM_VITERBI_ENGINE_SYNTHESIS_COMPLETE
exit
