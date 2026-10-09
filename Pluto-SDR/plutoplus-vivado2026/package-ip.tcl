# Package the unmodified ADI library IP in the isolated migration checkout.
set root [file dirname [file normalize [info script]]]
set ::env(ADI_IGNORE_VERSION_CHECK) 1
foreach lib {util_cdc util_axis_fifo axi_dmac axi_ad9361 util_pack/util_cpack2 util_pack/util_upack2} {
    cd [file join $root hdl library $lib]
    source [file tail $lib]_ip.tcl
    close_project
}
puts "PLUTO_LIBRARY_PACKAGING_COMPLETE"
