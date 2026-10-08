set root [file dirname [file normalize [info script]]]
open_project [file join $root build pn15 pluto_pn15.xpr]
open_bd_design [lindex [get_files *.bd] 0]
select_objects [get_bd_cells pn15_tx]
