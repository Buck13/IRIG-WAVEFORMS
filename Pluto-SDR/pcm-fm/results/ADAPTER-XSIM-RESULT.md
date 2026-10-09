# PN15 PCM-FM adapter verification

XSIM 2026.1 PASS: 268280 exact signed I/Q samples compared with the frozen
integer reference. Continuous requests cover all 262136 samples of a PN15
period. Three further 2048-sample cases cover request gaps, alternate seed,
and restart. No FIFO overflow or underflow assertion occurred.

The synchronized wrapper was compared against the same output sequence after
prefill. DMA bypass, channel enable loss, and startup zero output were checked.
Raw simulator evidence is in `adapter-xsim-transcript.txt`.

The testbench uses a 100 MHz clock and stresses one request per clock. Actual
output sample rate on the Pluto remains controlled by its TX request interface.
This is RTL simulation evidence, not a physical PCM-FM loopback result.
