# Separate receiver-only image with manual timing and epoch controls.
# The stock interpolation/decimation FIRs are bypassed to release 44 DSP48s.
set root [file dirname [file normalize [info script]]]
set destination [file join $root build cpm-h-rx-manual]
if {[file exists $destination]} {error "Manual CPM-H RX project already exists; refusing to overwrite it"}
open_project [file join $root hdl projects pluto pluto.xpr]
save_project_as pluto_cpm_h_rx_manual $destination
set bd [lindex [get_files *.bd] 0]
if {![string match -nocase "${destination}/*" [file normalize $bd]]} {error "Copied block design is outside isolated project"}
open_bd_design $bd

# This image only receives.  Use the ADI core's supported parameter to remove
# the unused DDS, IQ-correction and TX user datapath from the FPGA fabric.
# The physical AD9361 interface/control pins remain available to the driver.
set_property CONFIG.DAC_DATAPATH_DISABLE 1 [get_bd_cells axi_ad9361]

set rxhdl [file join $root .. cpm-h receiver hardware]
foreach source {
  cpm_rx_observation_adapter cpm_template_rom6 cpm_correlation_bank
  cpm_receiver_pkg cpm_schedule_pkg cpm_state_scheduler cpm_metric_tdp_ram
  cpm_metric_banks cpm_phase_acs4 cpm_viterbi_engine cpm_survivor_traceback
  cpm_viterbi_decoder cpm_h_detector cpm_rx_manual_frontend cpm_pn15_quality
  pluto_cpm_rx_controlled
} {
  add_files -norecurse [file join $rxhdl ${source}.vhd]
  set_property FILE_TYPE {VHDL 2008} [get_files *${source}.vhd]
}
update_compile_order -fileset sources_1
add_files -fileset constrs_1 -norecurse [file join $root cpm-h-rx-clock-groups.xdc]
source [file join $root hdl projects scripts adi_board.tcl]
set sys_zynq 1
set sys_cpu_interconnect_index [get_property CONFIG.NUM_MI [get_bd_cells axi_cpu_interconnect]]

# Remove the two external FIR hierarchies. The AD9361 internal filters remain active.
foreach pin {
  axi_ad9361/dac_data_i0 axi_ad9361/dac_data_q0
  tx_upack/fifo_rd_data_0 tx_upack/fifo_rd_data_1
  tx_upack/enable_0 tx_upack/enable_1
  cpack/enable_0 cpack/enable_1 cpack/fifo_wr_data_0 cpack/fifo_wr_data_1
  cpack/fifo_wr_en
} {
  set p [get_bd_pins $pin]
  set n [get_bd_nets -quiet -of_objects $p]
  if {[llength $n]} {disconnect_bd_net $n $p}
}
# logic_or input 1 was driven by TX FIR valid.
set p [get_bd_pins logic_or/Op1]
set n [get_bd_nets -quiet -of_objects $p]
if {[llength $n]} {disconnect_bd_net $n $p}
ad_connect tx_upack/fifo_rd_data_0 axi_ad9361/dac_data_i0
ad_connect tx_upack/fifo_rd_data_1 axi_ad9361/dac_data_q0
ad_connect axi_ad9361/dac_enable_i0 tx_upack/enable_0
ad_connect axi_ad9361/dac_enable_q0 tx_upack/enable_1
ad_connect axi_ad9361/dac_valid_i0 logic_or/Op1
ad_connect axi_ad9361/adc_enable_i0 cpack/enable_0
ad_connect axi_ad9361/adc_enable_q0 cpack/enable_1
ad_connect axi_ad9361/adc_data_i0 cpack/fifo_wr_data_0
ad_connect axi_ad9361/adc_data_q0 cpack/fifo_wr_data_1
ad_connect axi_ad9361/adc_valid_i0 cpack/fifo_wr_en
delete_bd_objs [get_bd_cells rx_fir_decimator] [get_bd_cells tx_fir_interpolator] [get_bd_cells decim_slice] [get_bd_cells interp_slice]

ad_ip_instance axi_gpio cpm_rx_control [list C_GPIO_WIDTH 9 C_ALL_OUTPUTS 1 C_IS_DUAL 1 C_GPIO2_WIDTH 32 C_ALL_INPUTS_2 1 C_DOUT_DEFAULT 0x00000000]
ad_cpu_interconnect 0x41220000 cpm_rx_control
create_bd_cell -type module -reference pluto_cpm_rx_controlled cpm_rx

ad_ip_instance xlconcat cpm_rx_concat [list NUM_PORTS 2 IN0_WIDTH 16 IN1_WIDTH 16]
ad_connect axi_ad9361/adc_data_i0 cpm_rx_concat/In0
ad_connect axi_ad9361/adc_data_q0 cpm_rx_concat/In1

ad_ip_instance util_axis_fifo cpm_rx_cdc [list DATA_WIDTH 32 ASYNC_CLK 1 ADDRESS_WIDTH 5]
ad_ip_instance util_vector_logic cpm_rx_reset_inv [list C_OPERATION {not} C_SIZE 1]
ad_connect axi_ad9361/rst cpm_rx_reset_inv/Op1
ad_connect cpm_rx_reset_inv/Res cpm_rx_cdc/s_axis_aresetn
ad_connect axi_ad9361/l_clk cpm_rx_cdc/s_axis_aclk
ad_connect axi_ad9361/adc_valid_i0 cpm_rx_cdc/s_axis_valid
ad_connect cpm_rx_concat/dout cpm_rx_cdc/s_axis_data
ad_connect sys_cpu_clk cpm_rx_cdc/m_axis_aclk
ad_connect sys_cpu_resetn cpm_rx_cdc/m_axis_aresetn
ad_connect VCC_1/dout cpm_rx_cdc/m_axis_ready
ad_connect cpm_rx_cdc/m_axis_valid cpm_rx/adc_valid
ad_connect cpm_rx_cdc/m_axis_data cpm_rx/adc_iq

ad_connect sys_cpu_clk cpm_rx/clk
ad_connect sys_cpu_reset cpm_rx/reset
ad_connect cpm_rx_control/gpio_io_o cpm_rx/control
ad_connect cpm_rx/status cpm_rx_control/gpio2_io_i

validate_bd_design
save_bd_design
generate_target all [get_files $bd]
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
update_compile_order -fileset sources_1
puts "CPM_H_RX_MANUAL_INTEGRATION_READY: $destination/pluto_cpm_h_rx_manual.xpr"
