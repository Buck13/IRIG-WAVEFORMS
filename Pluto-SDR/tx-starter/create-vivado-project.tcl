# Standalone core project only. This is not the Pluto board project.
set root [file normalize [file dirname [info script]]]
set requested_part xc7z010clg400-1
set selected_part [get_parts -quiet $requested_part]
if {[llength $selected_part] == 0} {
    set selected_part [lindex [get_parts] 0]
    puts "NOTE: $requested_part is not installed. Core-only fallback part: $selected_part"
}
set outdir [file join $root build vivado-vhdl]
create_project -force tx_vhdl_core $outdir -part $selected_part
set_property target_language VHDL [current_project]
foreach name {bpsk_mapper pn15_generator pn15_bpsk_tx} {
    read_vhdl -vhdl2008 [file join $root vhdl ${name}.vhd]
}
set_property top pn15_bpsk_tx [get_filesets sources_1]
set tb [file join $root sim pn15_bpsk_vhdl_tb.vhd]
add_files -fileset sim_1 -norecurse $tb
set_property file_type {VHDL 2008} [get_files $tb]
foreach name {pn15_default.mem pn15_alternate.mem} {
    add_files -fileset sim_1 -norecurse [file join $root build vhdl-sim $name]
}
set_property top pn15_bpsk_vhdl_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set f [open [file join $outdir TARGET.txt] w]
puts $f "Requested Pluto reference part: $requested_part"
puts $f "Selected standalone-core project part: $selected_part"
puts $f "No Pluto BSP, RF interface, pin constraints or firmware packaging in this project."
close $f
# OOC synthesis verifies RTL elaboration/inference, not board timing or RF behavior.
synth_design -top pn15_bpsk_tx -mode out_of_context -part $selected_part
report_utilization -file [file join $outdir core-utilization.rpt]
write_checkpoint -force [file join $outdir tx_core_synth.dcp]
close_project
