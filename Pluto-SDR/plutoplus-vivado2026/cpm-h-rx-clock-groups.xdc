# The AD9361 receive clock is independent of the Zynq processing-system clock.
# Both crossings in this image use asynchronous FIFOs (ADI ADC DMA and cpm_rx_cdc).
set_clock_groups -asynchronous \
  -group [get_clocks rx_clk] \
  -group [get_clocks clk_fpga_0]
