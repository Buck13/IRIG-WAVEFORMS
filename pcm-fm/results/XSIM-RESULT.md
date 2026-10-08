# PCM-FM XSIM result

Vivado/XSIM 2026.1, 2026-10-08: PASS.

268280 accepted samples compared exactly for signed 16-bit I/Q and unsigned
32-bit phase. No alignment fitting or tolerance was used. Cases: PN15 full
period 262136 samples; positive constant 1024; negative constant 1024;
alternating bits 2048; alternate PN15 seed 2048.

The testbench checked the 11-clock output latency and valid pattern, inserted
pseudo-random gaps, flushed pending samples, and reset with samples in flight.
See `xsim-transcript.txt` for the simulator evidence and `../HDL.md` for reruns.

This establishes RTL simulation equivalence only. Synthesis, timing closure,
resource utilization and Pluto PCM-FM transmission remain pending.
