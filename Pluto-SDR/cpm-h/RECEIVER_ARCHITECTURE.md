# CPM-H receiver: Python-to-VHDL architecture check

## What is already proved

The current coherent Python detector is mathematically consistent with the
transmitter. It has passed noiseless, exhaustive-search, and noisy-model tests.
It also decoded the Pluto TX1-to-RX2 hardware capture at 1 Mbit/s with zero
errors over 1024 checked bits.

The hardware capture result proves that the transmitter waveform and trellis
branch model agree. It does not yet prove acquisition or tracking because the
verification script uses the known PN15 sequence to find timing, carrier phase,
gain, index parity, and the starting trellis state.

## Existing detector

The detector state is `(p, b, c)`:

- `p`: completed-pulse phase, modulo 32;
- `b`: previous quaternary symbol;
- `c`: symbol before `b`.

The alternating modulation index parity is known externally. After startup,
256 states are reachable per dibit interval. Each state tests four possible
new dibits, giving 1024 branch evaluations per dibit. At 1 Mbit/s there are
500,000 dibits/s, so the literal Python loops imply 512 million branch metrics
per second. Each Python metric currently compares 32 complex samples.

At a 100 MHz FPGA clock, only 200 clocks are available per dibit. A direct
translation of the Python nested loops cannot meet real-time operation. The
trellis and state transition equations can be translated, but the branch
metric computation must be reorganized and parallelized.

## Receiver blocks

```text
AD9361 RX IQ
    |
    v
DC removal / level control
    |
    v
coarse frequency correction
    |
    v
preamble correlation and dibit timing
    |
    +--> H=4/H=5 parity and frame boundary
    |
    v
carrier phase tracking
    |
    v
CPM branch-metric engine
    |
    v
add-compare-select path metrics
    |
    v
survivor memory and traceback
    |
    v
recovered dibits / bits
```

## Safe implementation order

1. **Fixed-point detector reference.** Make an integer Python model using the
   Pluto's signed IQ samples, finite-width branch/path metrics, renormalization,
   and a bounded traceback. It must reproduce the floating-point decisions on
   simulations and on the saved zero-error hardware capture.
2. **Metric-engine experiment.** Reduce the 32 input samples to a smaller set
   of sufficient or near-sufficient correlation values, then measure BER loss.
   Choose parallelism from the measured operation count rather than translating
   1024 x 32 sample comparisons literally.
3. **VHDL detector core with ideal synchronization.** Supply dibit-aligned,
   carrier-corrected IQ and a known parity/start condition. Verify it against
   vectors exported by the fixed-point Python model.
4. **Acquisition and tracking.** Add preamble correlation, sample timing,
   frequency correction, carrier phase tracking, and parity detection.
5. **Pluto integration.** Put the receiver in a separate experimental image,
   measure resources/timing, and compare its decoded output with the Python
   result from the same captured IQ.

## Immediate next deliverable

The next code should be the fixed-point Python detector reference, not VHDL.
It will define every width, saturation rule, metric renormalization interval,
traceback depth, and input scaling rule. Those choices become the VHDL
interface contract and golden-vector generator.
