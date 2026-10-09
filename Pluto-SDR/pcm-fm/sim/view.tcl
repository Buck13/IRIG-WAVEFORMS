add_wave /pcm_fm_tb/clk
add_wave /pcm_fm_tb/reset
add_wave /pcm_fm_tb/ce
add_wave -radix dec /pcm_fm_tb/nrz
add_wave /pcm_fm_tb/valid
add_wave -radix dec /pcm_fm_tb/io
add_wave -radix dec /pcm_fm_tb/qo
add_wave -radix hex /pcm_fm_tb/phase
save_wave_config pcm_fm_view.wcfg
puts "PCM_FM_WAVEFORM_VIEW_READY"
