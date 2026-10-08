log_wave -r /pluto_tx_top_tb/*
add_wave /pluto_tx_top_tb/clk
add_wave /pluto_tx_top_tb/reset
add_wave /pluto_tx_top_tb/control
add_wave /pluto_tx_top_tb/dut/select_sync
add_wave /pluto_tx_top_tb/ei
add_wave /pluto_tx_top_tb/eq
add_wave /pluto_tx_top_tb/request
add_wave /pluto_tx_top_tb/dut/source/core/pn/symbol_bit
add_wave -radix dec /pluto_tx_top_tb/ti
add_wave -radix dec /pluto_tx_top_tb/tq
run 10us
save_wave_config pn15_bpsk_view.wcfg
puts "PN15_WAVEFORM_VIEW_READY"
