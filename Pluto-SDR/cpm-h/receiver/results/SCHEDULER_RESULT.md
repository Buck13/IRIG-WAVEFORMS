# Two-lane Viterbi scheduler result

The steady ARTM CPM trellis contains 256 active states. Its active phase-state
set follows a four-dibit epoch, so the scheduler exports four transition tables.
For each destination it supplies the four predecessor metric addresses, four
base-correlation addresses, and four completed-phase indexes.

## Verification

- all four Python schedules exactly match direct trellis updates;
- two destinations are issued per clock;
- all 512 VHDL schedule cycles (four epochs x 128 clocks) match Python;
- the four predecessors are ordered by older-symbol state, mapping candidate
  0..3 to metric memory bank 0..3;
- one dibit completes in 128 issue clocks, leaving 72 clocks at 100 MHz and
  1 Mbit/s for pipeline flush and control.

## Metric-memory finding

A functional ping-pong metric-bank prototype passes write, minimum tracking,
bank swap, and normalized-read simulation. It avoids a separate normalization
pass by saving the minimum with each completed bank and subtracting it when the
next symbol reads that bank.

Vivado rejected the original asynchronous-read prototype for BRAM inference and
began expanding it into 515 48-bit registers plus large muxes. It was replaced
with four synchronous one-write/two-read banks on each ping-pong side. Each
active bank supplies one predecessor to each ACS lane while the inactive side
accepts destination writes. The one-clock read latency remains within the
72-clock scheduling margin.

Vivado 2026.1 synthesis for `xc7z010clg400-1` now reports a final block-RAM
mapping for all eight 64 x 48 memories, with zero errors and zero critical
warnings. Standalone utilization for the complete metric-bank subsystem is:

- 1,190 LUTs (6.76% of the XC7Z010);
- 156 registers (0.44%);
- 8 RAMB36E1 plus 8 RAMB18E1, equal to 12 of 60 block-RAM tiles (20%).

The GHDL regression also passes the synchronous read-valid timing, ping-pong
write and swap, minimum tracking, and normalized reads. The other receiver
regressions remain passing: 384 branch metrics, 192 correlations, 256 phase/ACS
vectors, and 512 scheduler jobs.
