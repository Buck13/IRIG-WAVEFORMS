# Selected PCM/FM filter reference

Decision: sixth-order Bessel-derived, causal 65-tap FIR at 2.5 MS/s,
312.5 kbit/s, h=0.7 and nominal deviation 109375 Hz. Use this reference for
subsequent HDL equivalence work. No HDL or RF compliance claim is made.

## Source and interpretation

[RCC 106-22 Chapter 2](https://www.irig106.org/docs/106-22/chapter2.pdf),
section 2.3.3.2, equations 2-9 through 2-14 and Table 2-3 describe filtered
PCM/FM. The recommended half-power corner is 0.7 times bit rate. The table
provides several Bessel orders; sixth order is our selection, not a uniquely
mandated order. This revision is the pinned reference, not a claim of latest edition.

The FIR is an approximation of that continuous-time response. It uses the
six tabulated complex poles, unity-DC residues, sampled impulse response,
65-tap truncation, DC normalization and a small frequency-scale calibration.
Coefficients are signed 18-bit with 17 fractional bits. The largest-magnitude
tap absorbs the quantization sum correction to preserve unity DC gain.
The taps are asymmetric: do not apply symmetric-FIR hardware optimizations.

## Measured acceptance

The engineering tolerances below are ours, not standard-specified tolerances:

| Check | Limit | Result |
|---|---:|---:|
| Quantized half-power corner error | <0.1% | -3.49 Hz / -0.00160% |
| Magnitude error versus analog, DC to corner | <0.01 dB | 0.000130 dB |
| Phase error versus analog, DC to corner | <0.002 rad | 0.000191 rad |
| -1 to +1 transition peak | <1.02 | 1.013702 |

Full PN15 sequence peak is 1.013723 versus 1.264538 for the old sinc prototype.
These sequence peaks differ from the isolated-transition measurements shown in
the comparison plot. DC group delay is 4.918 samples, not the old 32-sample delay.
Full-period integer-versus-floating I/Q RMS error is approximately 0.088697%.
The integer FIR absolute coefficient sum is 133424, within the 21-bit sum bound.

## Frozen handoff and remaining checks

`results/reference-sha256.json` identifies the exact Q17 coefficients, signed
sine ROM and 4096-sample HDL vectors. Full-period software checks are reproduced
by `pcm_fm.py`. `validate_filter.py` compares responses and transition behavior;
both notebooks embed the comparison plot.

The spectral figure is a relative windowed periodogram, not the standard's
measurement procedure or an RF mask pass/fail result. Analog reconstruction,
Pluto interpolation, RF impairments and receiver performance remain untested.
The next stage is VHDL scheduling and exact sample-by-sample XSIM equivalence.

Update: the selected reference now has a matching VHDL core with passing XSIM
verification; see [HDL.md](HDL.md). Synthesis and RF verification remain pending.
