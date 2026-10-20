set root [file normalize [file dirname [info script]]]
read_vhdl -vhdl2008 [file join $root hdl cpm_rom_pkg.vhd]
read_vhdl -vhdl2008 [file join $root hdl cpm_h_nco_pkg.vhd]
read_vhdl -vhdl2008 [file join $root hdl cpm_h_phase_core.vhd]
read_vhdl -vhdl2008 [file join $root hdl cpm_h_iq_rom.vhd]
read_vhdl -vhdl2008 [file join $root hdl cpm_h_tx_core.vhd]
synth_design -top cpm_h_tx_core -part xc7z010clg400-1
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root results target-synthesis-utilization.rpt]
report_timing_summary -file [file join $root results target-synthesis-timing.rpt]
puts CPM_H_TARGET_SYNTHESIS_COMPLETE
exit
