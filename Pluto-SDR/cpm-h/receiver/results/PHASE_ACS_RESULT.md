# CPM phase-score and ACS lane

`cpm_phase_acs4.vhd` implements the four-predecessor add-compare-select
operation for one CPM destination state. Each candidate uses its completed-phase
index to rotate a reusable complex correlation, adds the resulting negative
correlation score to the predecessor path metric, and competes for the minimum.
The output is the winning metric and a two-bit survivor predecessor index.

## Fixed-point result

The 16-observation correlation is shifted right by nine bits before phase
scoring, reducing it to signed 18 bits. Q15 sine/cosine coefficients then fit
one DSP48E1 per real multiply. This normalization caused:

- zero bit errors on the 1024-bit Pluto capture;
- zero fixed-versus-floating correlation decisions;
- zero decision differences against direct squared-distance detection over the
  current 12, 6, 3 and 0 dB noisy tests;
- 256/256 Python-generated VHDL ACS vectors passing.

## XC7Z010 synthesis

Vivado 2026.1 standalone synthesis for `xc7z010clg400-1` reports one four-way
ACS lane using 631 slice LUTs, 51 registers, 8 DSP48E1 blocks and no BRAM.
The initial 32-bit correlation input used 16 DSPs; the verified normalization
halved that cost.

This is an out-of-context resource result. The current report does not constrain
input-to-register paths, so it is not a valid 100 MHz timing-closure claim.
Pipeline registers and the scheduler must be added before full timing evaluation.

At 256 destinations and 200 clocks per dibit, two one-destination-per-clock ACS
lanes meet the raw scheduling rate. A time-shared/pipelined alternative may
reduce DSP use and will be evaluated with the correlation lanes in the complete
receiver schedule.
