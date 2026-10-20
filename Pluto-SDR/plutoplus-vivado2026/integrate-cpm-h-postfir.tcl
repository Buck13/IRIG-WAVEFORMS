# Separate ARTM CPM-H image. Instance names retain the audited selector CDC flow.
set root [file dirname [file normalize [info script]]]
set destination [file join $root build cpm-h-postfir]
if {[file exists $destination]} {error "CPM-H project already exists; refusing to overwrite it"}
open_project [file join $root hdl projects pluto pluto.xpr]
save_project_as pluto_cpm_h $destination
set bd [lindex [get_files *.bd] 0]
if {![string match -nocase "${destination}/*" [file normalize $bd]]} {error "Copied block design is outside isolated project: $bd"}
open_bd_design $bd
set hdl [file join $root .. cpm-h hdl]
foreach source {cpm_rom_pkg cpm_h_nco_pkg cpm_h_phase_core cpm_h_iq_rom cpm_h_tx_core pluto_cpm_h_adapter pluto_cpm_h_top} {
  add_files -norecurse [file join $hdl ${source}.vhd]
  set_property FILE_TYPE {VHDL 2008} [get_files *${source}.vhd]
}
update_compile_order -fileset sources_1
source [file join $root hdl projects scripts adi_board.tcl]
set sys_zynq 1
set sys_cpu_interconnect_index [get_property CONFIG.NUM_MI [get_bd_cells axi_cpu_interconnect]]
ad_ip_instance axi_gpio pn15_control [list C_GPIO_WIDTH 1 C_ALL_OUTPUTS 1 C_IS_DUAL 0 C_DOUT_DEFAULT 0x00000000]
ad_cpu_interconnect 0x41210000 pn15_control
create_bd_cell -type module -reference pluto_cpm_h_top pn15_tx
ad_connect axi_ad9361/l_clk pn15_tx/clk
ad_connect axi_ad9361/rst pn15_tx/reset
ad_connect pn15_control/gpio_io_o pn15_tx/select_async
ad_connect axi_ad9361/dac_enable_i0 pn15_tx/enable_i
ad_connect axi_ad9361/dac_enable_q0 pn15_tx/enable_q
ad_connect axi_ad9361/dac_valid_i0 pn15_tx/sample_request
foreach {dac_pin fir_channel component} {dac_data_i0 0 i dac_data_q0 1 q} {
  set pin [get_bd_pins axi_ad9361/$dac_pin]
  disconnect_bd_net [get_bd_nets -of_objects $pin] $pin
  ad_connect tx_fir_interpolator/data_out_$fir_channel pn15_tx/dma_$component
  ad_connect pn15_tx/tx_$component axi_ad9361/$dac_pin
}
validate_bd_design
save_bd_design
generate_target all [get_files $bd]
foreach constraint [list [file join $root hdl projects pluto dma_metadata_cdc.xdc] [file join $root pn15_control_cdc.xdc]] {
  if {![llength [get_files -quiet *[file tail $constraint]]]} {add_files -fileset constrs_1 -norecurse $constraint}
  set_property USED_IN_SYNTHESIS false [get_files *[file tail $constraint]]
  set_property PROCESSING_ORDER LATE [get_files *[file tail $constraint]]
}
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveFanoutOpt [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
update_compile_order -fileset sources_1
puts "CPM_H_POSTFIR_INTEGRATION_READY: $destination/pluto_cpm_h.xpr"
