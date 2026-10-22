# Integrated CPM-H Viterbi engine

`cpm_viterbi_engine.vhd` packages the steady-state trellis scheduler, ping-pong
path-metric memories, two four-predecessor phase/ACS lanes, metric
renormalization, and aligned survivor outputs behind one receiver interface.
The caller loads 64 signed complex correlations for a dibit, supplies its
four-phase epoch, and pulses `start`. The engine emits two destination survivor
choices and their path metrics per valid clock, then pulses `done` after all 256
states have been committed and the metric banks have swapped.

The survivor stream is intentionally exposed as a write interface. A bounded
survivor-history RAM and traceback controller consume this stream in the next
receiver stage. The 64 waveform correlators are also upstream of this block.

## Verification

The deterministic Python model initializes state zero to metric zero and all
other states to `2^24`, then computes one complete epoch from 64 complex
correlations. GHDL checks all 128 two-lane output cycles against that model:

- 256 destination addresses match;
- 256 two-bit predecessor choices match;
- 256 signed 48-bit path metrics match;
- `ready`, `busy`, and `done` sequencing passes;
- the complete receiver regression remains passing.

The correlation lookup, DSP multiplies, candidate arithmetic, and four-way
comparison are pipelined. The balanced comparison tree preserves two
destinations per clock while meeting the 100 MHz target.

## XC7Z010 synthesis

Vivado 2026.1 synthesis for `xc7z010clg400-1` completed with zero errors and
zero critical warnings. The synthesized timing estimate meets the 10 ns clock:

- setup WNS: +1.942 ns;
- hold WHS: +0.073 ns;
- 0 failing setup or hold endpoints.

Standalone engine utilization is:

- 2,477 LUTs (14.07%), including 384 distributed-RAM LUTs;
- 1,710 registers (4.86%);
- 22 of 60 block-RAM tiles (36.67%);
- 16 of 80 DSP48E1 blocks (20%).

These figures include the scheduler ROMs and both path-metric banks. They do not
include the upstream 64-correlation generator, survivor-history RAM, traceback,
synchronization, or Pluto integration logic. Final acceptance still requires
placed-and-routed timing in the complete Pluto image.