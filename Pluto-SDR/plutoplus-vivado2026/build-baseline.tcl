set root [file dirname [file normalize [info script]]]
set target xc7z010clg400-1
if {[llength [get_parts -quiet $target]] != 1} {
    error "Missing device support for $target. Add Zynq-7000 support to this Vivado installation. No substitute target is allowed for a board build."
}
set ::env(ADI_IGNORE_VERSION_CHECK) 1
cd [file join $root hdl projects pluto]
source system_project.tcl
