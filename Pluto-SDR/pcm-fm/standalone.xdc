# Standalone engineering target. Actual Pluto integration constraints are separate.
create_clock -name core_clk -period 10.000 [get_ports clk]
set_input_delay -clock core_clk -max 2.000 [get_ports {reset sample_ce nrz_in[*]}]
set_input_delay -clock core_clk -min 0.000 [get_ports {reset sample_ce nrz_in[*]}]
set_output_delay -clock core_clk -max 2.000 [get_ports {i_out[*] q_out[*] out_valid phase_debug[*]}]
set_output_delay -clock core_clk -min 0.000 [get_ports {i_out[*] q_out[*] out_valid phase_debug[*]}]
