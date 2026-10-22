# Correlation front end and complete detector result

The receiver now has a hardware path from aligned Q12 IQ observations to traceback-decoded dibits.

## Implemented blocks

- cpm_template_rom6.vhd stores the two parity sets of 64 CPM-H base waveforms at 16 evenly spaced observations per dibit.
- cpm_correlation_bank.vhd uses six complex MAC lanes. It accepts one observation every 12 clocks, accumulates all 64 correlations, shifts the results right by nine bits, and drains Q18 correlations while accumulating the next dibit.
- cpm_h_detector.vhd connects the correlation bank to the existing 256-state Viterbi engine and 32-dibit survivor traceback block.
- generate_correlation_bank.py regenerates both the VHDL template ROM and independent simulation vectors from the fixed-point Python reference.

At 100 MHz and 1 Mbit/s, a dibit lasts 200 clocks. Six lanes need 11 work cycles per observation and the pipelined input interval is 12 clocks. The completed 64-entry correlation set drains during the next dibit, so correlation generation and Viterbi processing overlap.

## Verification

The self-checking GHDL testbench passed 128 correlation values covering both H=4 and H=5 parity cases. The complete receiver regression also passed the existing 384 branch-metric samples, 192 single-lane correlation samples, 256 phase/ACS vectors, 512 scheduler jobs, metric-memory test, 128 integrated Viterbi writes, and nine bounded-traceback outputs.

Vivado 2026.1 synthesized the complete cpm_h_detector for xc7z010clg400-1 at 100 MHz:

| Resource | Used | XC7Z010 | Percent |
|---|---:|---:|---:|
| Slice LUTs | 6,448 | 17,600 | 36.64% |
| Slice registers | 8,313 | 35,200 | 23.62% |
| BRAM tiles | 23 | 60 | 38.33% |
| DSP slices | 40 | 80 | 50.00% |

Timing passed with setup WNS **+0.777 ns** and hold WHS **+0.073 ns**.

These figures cover the aligned-sample correlator, Viterbi engine, survivor memory, and traceback. They do not include acquisition, frequency/phase tracking, dibit timing recovery, Pluto AXI-stream adaptation, or control/status registers. Those synchronization and integration blocks are the next receiver milestone.
