# PCM-FM VHDL architecture

`hdl/pcm_fm_core.vhd` implements the frozen PCM-FM arithmetic. Constants are
exported by `sim/generate.py` from the hash-verified coefficient and sine files.
No Pluto hardware is accessed by these scripts.

## Interface and latency

The input is a signed two-bit NRZ sample, exactly -1 or +1. `sample_ce=1`
accepts it on a rising edge. `reset=1` takes precedence and synchronously clears
history, phase and all valid flags, discarding pending samples. There is no
output ready/backpressure port; the consumer must accept every valid output.

| Edge relative to acceptance | Operation |
|---:|---|
| 0 | Capture signed coefficient contributions and shift NRZ history |
| 1–7 | Seven registered levels of a zero-padded 128-leaf adder tree |
| 8 | 21 x 29-bit signed frequency-scaling product |
| 9 | Signed nearest rounding, ties away from zero; 32-bit increment |
| 10 | Update unsigned 32-bit modulo phase |
| 11 | Registered sine/cosine lookup and output valid |

One accepted input per clock is supported by the RTL structure. The test clock
is 100 MHz, which is a simulation choice, not a timing-closure claim. Input
bubbles propagate through valid flags while pending outputs drain. Output data
holds during invalid cycles. A new valid input may coincide with an old output.

The 65 taps are asymmetric. Input levels allow coefficient add/subtract rather
than tap multipliers. Frequency scaling remains a multiplier. Table inference,
DSP/BRAM utilization and timing require synthesis and implementation; no resource
numbers are claimed here.

## Verification and waveforms

Run `./run-sim.ps1` from PowerShell. It regenerates five software-reference cases,
compiles VHDL-2008, elaborates and runs XSIM. The testbench compares exact phase,
I and Q, checks valid on the precise expected edge, drains the pipeline, and
checks synchronous reset including a reset with samples in flight.

Cases: one complete PN15 period at eight samples/bit (continuous input), constant
+1, constant -1, alternating bits, and a different PN15 seed. The latter cases
insert deterministic pseudo-random input gaps. The input stream is supplied by
the testbench; an HDL PN15/sample-hold wrapper and Pluto integration are pending.

The local waveform database is `build/xsim/pcm_fm.wdb`. Run
`./show-waveforms.ps1` to open the saved clock/reset/input/valid/I/Q/phase signals
in the XSIM GUI. Zoom into the first microsecond to see reset and pipeline fill.
Generated simulation files remain local under ignored `build/`.
