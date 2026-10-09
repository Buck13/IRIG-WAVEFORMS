set root [file dirname [file normalize [info script]]]
open_checkpoint [file join $root hdl projects pluto pluto.runs impl_1 system_top_routed.dcp]
report_timing -from [get_clocks rx_clk] -to [get_clocks clk_fpga_0] -max_paths 5 -file cdc_rx_to_cpu.rpt
report_timing -from [get_clocks clk_fpga_0] -to [get_clocks rx_clk] -max_paths 5 -file cdc_cpu_to_rx.rpt
report_exceptions -coverage -file cdc_exceptions.rpt
report_cdc -details -file cdc_analysis.rpt
foreach pattern {*i_src_dest_bl_fifo*i_raddr_sync*cdc_sync_stage1_reg* *i_dest_req_fifo*cdc_sync_fifo_ram_reg*} {
  set cells [get_cells -hier -filter "NAME =~ $pattern"]
  puts "CDC_MATCH $pattern : [llength $cells] : $cells"
}
