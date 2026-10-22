set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root cpm_template_rom6.vhd]
read_vhdl -vhdl2008 [file join $root cpm_correlation_bank.vhd]
synth_design -top cpm_correlation_bank -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root .. results correlation-bank-synthesis-utilization.rpt]
report_timing_summary -delay_type min_max -max_paths 10 -file [file join $root .. results correlation-bank-synthesis-timing.rpt]
puts CPM_CORRELATION_BANK_SYNTHESIS_COMPLETE
exit
