set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root cpm_receiver_pkg.vhd]
read_vhdl -vhdl2008 [file join $root cpm_metric_banks.vhd]
synth_design -top cpm_metric_banks -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root .. results metric-banks-synthesis-utilization.rpt]
puts CPM_METRIC_BANKS_SYNTHESIS_COMPLETE
exit
