# Separate PCM-FM image. pn15_tx/control instance names retained for audited CDC selectors.
set root [file dirname [file normalize [info script]]]
set destination [file join $root build pcm-fm]
if {[file exists $destination]} {error "PCM-FM project already exists; refusing to overwrite it"}
open_project [file join $root hdl projects pluto pluto.xpr]
save_project_as pluto_pcm_fm $destination
set bd [lindex [get_files *.bd] 0]
if {![string match -nocase "${destination}/*" [file normalize $bd]]} {
  error "Copied block design is outside isolated project: $bd"
}
open_bd_design $bd
set hdl [file join $root .. pcm-fm hdl]
foreach source {pcm_fm_tables pcm_fm_core pluto_pcm_fm_adapter pluto_pcm_fm_top} {
  add_files -norecurse [file join $hdl ${source}.vhd]
  set_property FILE_TYPE {VHDL 2008} [get_files *${source}.vhd]
}
update_compile_order -fileset sources_1
source [file join $root hdl projects scripts adi_board.tcl]
set sys_zynq 1
set sys_cpu_interconnect_index [get_property CONFIG.NUM_MI [get_bd_cells axi_cpu_interconnect]]
ad_ip_instance axi_gpio pn15_control [list C_GPIO_WIDTH 1 C_ALL_OUTPUTS 1 C_IS_DUAL 0 C_DOUT_DEFAULT 0x00000000]
ad_cpu_interconnect 0x41210000 pn15_control
create_bd_cell -type module -reference pluto_pcm_fm_top pn15_tx
set_property CONFIG.SAMPLES_PER_SYMBOL 8 [get_bd_cells pn15_tx]
ad_connect axi_ad9361/l_clk pn15_tx/clk
ad_connect axi_ad9361/rst pn15_tx/reset
ad_connect pn15_control/gpio_io_o pn15_tx/select_async
ad_connect tx_fir_interpolator/enable_out_0 pn15_tx/enable_i
ad_connect tx_fir_interpolator/enable_out_1 pn15_tx/enable_q
ad_connect tx_fir_interpolator/valid_out_0 pn15_tx/sample_request
foreach {channel component} {0 i 1 q} {
  set pin [get_bd_pins tx_fir_interpolator/data_in_$channel]
  disconnect_bd_net [get_bd_nets -of_objects $pin] $pin
  ad_connect tx_upack/fifo_rd_data_$channel pn15_tx/dma_$component
  ad_connect pn15_tx/tx_$component tx_fir_interpolator/data_in_$channel
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
puts "PCM_FM_INTEGRATION_READY: $destination/pluto_pcm_fm.xpr"
