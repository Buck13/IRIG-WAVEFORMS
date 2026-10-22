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

Vivado rejected the asynchronous-read prototype for BRAM inference and began
expanding it into 515 48-bit registers plus large muxes. That implementation is
therefore a simulation reference only. The accepted hardware version must use
four synchronous true-dual-port banks per ping-pong side. Each bank services one
predecessor from each ACS lane; the inactive side accepts destination writes.
This adds one scheduled read-latency clock but remains within the 72-clock
margin.
