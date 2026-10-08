# Bound only the ARM control bit's crossing to synchroniser stage one.
set first_stage [get_cells -quiet -hier -filter {NAME =~ *pn15_tx*select_meta_reg && IS_SEQUENTIAL}]
# Selector cardinality is checked by audit-pn15-cdc.tcl, outside read_xdc.
set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to $first_stage [get_property PERIOD [get_clocks clk_fpga_0]]
