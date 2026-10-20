set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root reference hardware cpm_rom_pkg.vhd]
read_vhdl -vhdl2008 [file join $root reference hardware cpm_core.vhd]
synth_design -top cpm_core -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root results reference-synthesis-utilization.rpt]
report_timing_summary -file [file join $root results reference-synthesis-timing.rpt]
puts CPM_H_REFERENCE_SYNTHESIS_COMPLETE
exit
