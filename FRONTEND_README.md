# SOQPSK-TG front end

This adds the first four receiver-front-end blocks:

1. Exact IRIG-106-TG pulse parameters and normalized frequency pulse.
2. Matched filter using the 8-bit pulse response.
3. Decision-directed carrier phase/frequency recovery.
4. Gardner timing recovery with fractional linear interpolation.

The implementation is a floating-point reference model intended to define
the fixed-point FPGA architecture. It must be regression-tested against noisy
waveforms before RTL coefficients are frozen.

The current BER sweep is intentionally a gate, not a performance claim: the
reduced four-state trellis is not yet sufficient for the full eight-bit pulse
memory. `calibrate_soqpsk.py` exports the exact-pulse Q15 filter and measured
branch-template coefficients; the next milestone replaces the reduced phase
observation with multi-symbol Laurent branch correlations.
