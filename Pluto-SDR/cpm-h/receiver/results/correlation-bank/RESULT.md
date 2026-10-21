# Factorized CPM correlation-bank result

The CPM branch template factors into a base waveform selected by `(H parity,
previous symbol, older symbol, candidate dibit)` and a completed-phase rotation
selected by `p`. For a steady interval this gives 64 base waveforms for the
active H parity instead of 1024 independently evaluated state branches.

For constant-envelope ideal templates, minimizing squared IQ error is exactly
equivalent to maximizing:

`Re(sum(rx * conjugate(base)) * exp(-j*2*pi*p/32))`.

## Verification

With 16 observations per dibit:

- exact floating-point factorization recovered the Pluto capture with 0 errors
  in 1024 bits;
- Q12 base/RX values and Q16 phase rotations also recovered 0 errors;
- fixed and floating factorized detectors had zero dibit differences;
- the factorized fixed-point and original direct squared-distance detectors had
  zero payload-decision differences in the 12, 6, 3 and 0 dB simulations
  (640 checked bits at each point);
- `cpm_complex_correlator.vhd` passed 192 Python-generated clock samples.

These finite tests establish equivalence for the implementation baseline. They
do not replace the longer BER, timing-offset, and carrier-error sweeps required
before freezing the receiver.

## Hardware implication

The steady workload is 64 x 16 = 1024 complex sample MACs plus 1024 phase
scores per dibit. At 100 MHz and 500 kdibit/s there are 200 clocks per dibit,
so a first schedule needs at least six complex-MAC lanes and six phase-score
lanes. Six conventional complex correlators use 24 real multipliers, or 18 with
a three-multiply complex-product form. This is intended for the separate
RX-focused image where TX/FIR resources can be removed; it is not expected to
fit beside every block in the current nearly full combined image.

The next block is the phase-score plus add-compare-select lane, followed by the
scheduler that feeds all 256 destination states and writes survivor decisions.
