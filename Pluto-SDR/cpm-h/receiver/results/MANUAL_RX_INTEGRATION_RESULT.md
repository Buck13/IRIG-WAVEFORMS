# Manual CPM-H receiver integration result

Vivado 2026.1 successfully synthesized, placed, routed and generated a
bitstream for the XC7Z010 Pluto+ receiver image. This is a separate RX-only
image; it does not contain the PCM-FM or CPM-H transmitter.

The image takes corrected RX1 I/Q samples from `axi_ad9361`, crosses them from
the AD9361 receive clock into the 100 MHz processing-system FPGA clock with an
asynchronous FIFO, selects 16 observations per dibit with a manually selected
timing offset, and feeds the complete 64-correlation/256-state CPM-H Viterbi
detector. The initial epoch is also selected manually. Automatic carrier,
timing and epoch acquisition are still future work.

To fit the complete detector, the stock external RX/TX FIR blocks are bypassed
and the ADI core's supported `DAC_DATAPATH_DISABLE` option removes the unused
TX datapath. The AD9361's internal filtering remains available. Post-route
resource use is:

- 11,714 / 17,600 LUTs (66.56%);
- 17,863 / 35,200 registers (50.75%);
- 25.5 / 60 block-RAM tiles (42.50%);
- 52 / 80 DSP48 blocks (65.00%).

Final timing passed with +0.011 ns setup slack and +0.011 ns hold slack. DRC
completed with zero errors. The radio clock and processor FPGA clock are
explicitly asynchronous; their data paths cross through asynchronous FIFOs.

The processor control/status interface is AXI GPIO at `0x41220000`:

- control bit 0: enable;
- control bit 1: restart pulse;
- control bits 6:2: timing offset, 0 through 31 raw samples;
- control bits 8:7: starting CPM epoch, 0 through 3;
- status bits 31:16: decoded-dibit count;
- status bit 6: decoded-valid pulse;
- status bits 5:4: latest decoded dibit;
- status bit 3: sticky detector overflow;
- status bit 2: sticky dropped observation;
- status bit 1: detector busy;
- status bit 0: manual alignment active.

Use `Pluto-SDR/live/cpm-h-rx-control.sh` on the Pluto to start, restart, stop
and inspect the receiver. The FPGA-manager payload is generated locally as
`plutoplus-vivado2026/artifacts/cpm-h-rx-manual/pluto_cpm_h_rx_manual.bit.bin`.
Its verified SHA-256 is
`33230B51FCBBF69145B5F876C90564BBEDC8CF65AC4F37CA4755741B6CD72B1E`.

This milestone proves that the complete receiver fits and closes timing. RF
hardware testing still requires loading the image, selecting the correct
timing offset/epoch, and comparing decoded output against the known PN15
sequence.
