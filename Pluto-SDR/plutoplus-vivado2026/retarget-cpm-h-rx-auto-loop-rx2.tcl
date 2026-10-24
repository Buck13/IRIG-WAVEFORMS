set root [file dirname [file normalize [info script]]]
open_project [file join $root build cpm-h-rx-auto-loop pluto_cpm_h_rx_auto_loop.xpr]
set bd [lindex [get_files *.bd] 0]
open_bd_design $bd
foreach pin {cpm_rx_concat/In0 cpm_rx_concat/In1} {
  set p [get_bd_pins $pin]
  set n [get_bd_nets -quiet -of_objects $p]
  if {[llength $n]} {disconnect_bd_net $n $p}
}
connect_bd_net [get_bd_pins axi_ad9361/adc_data_i1] [get_bd_pins cpm_rx_concat/In0]
connect_bd_net [get_bd_pins axi_ad9361/adc_data_q1] [get_bd_pins cpm_rx_concat/In1]
validate_bd_design
save_bd_design
generate_target all [get_files $bd]
update_compile_order -fileset sources_1
puts CPM_H_RX_AUTO_LOOP_RETARGETED_TO_RX2
exit
