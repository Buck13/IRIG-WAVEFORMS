# Pluto+ ARTM CPM-H transmitter

This is a separate FPGA-image project for moving the validated ARTM multi-h
CPM model onto the XC7Z010 Pluto+. It does not modify or replace the working
PCM-FM source tree or image.

## Imported validated baseline

`reference/` is a snapshot copied from the earlier CPM-H study. It contains
the three executed notebooks, reusable Python transmitter/demodulator models,
the 24-bit/32-samples-per-symbol VHDL phase core, its coefficient package and
the 6000-cycle golden test. The source snapshot reported:

- maximum fixed-point phase error 0.000514 degrees over 4096 random symbols;
- a 6000-vector GHDL pass covering reset, stalls, starvation and wrap;
- no FPGA synthesis, target timing, I/Q NCO or Pluto interface in that version.

The imported snapshot is retained for traceability. Pluto-targeted RTL belongs
in `hdl/`, tests in `sim/`, and generated reports in `results/`.

## Pluto target and resource constraint

Target: `xc7z010clg400-1`. The validated Vivado 2026.1 baseline already uses
4304/4400 slices and 72/80 DSP48E1 blocks. The PCM-FM image uses 4351 slices
and 74 DSPs. CPM-H therefore cannot be implemented as an unrestricted direct
translation.

The target architecture will:

1. keep the ARTM alternating modulation indices H=4,5 (h=1/4,5/16), ternary
   pulse memory of three symbols, 32 samples/symbol and 24-bit phase;
2. replace the reference core's three sample multipliers with precomputed
   signed pulse banks stored in BRAM;
3. create I/Q with a BRAM sine table, avoiding a large CORDIC and further DSPs;
4. reuse the proven post-interpolator source selector and continuous zero-DMA
   clocking scheme from PCM-FM;
5. make a new CPM-H `.bit.bin`; the PCM-FM image remains separately loadable.

The first gate is exact sample-by-sample equivalence to the imported Python
model. The second is standalone synthesis/resource measurement. Full Pluto
integration starts only after both pass.

## Baseline results

Vivado 2026.1 XSIM reproduced the imported result exactly: all 6000 golden
clock vectors passed. Standalone synthesis for `xc7z010clg400-1` used 306 LUTs,
91 registers, zero BRAM tiles and zero DSP48s. The unpipelined combinational
core missed a 100 MHz constraint by 1.944 ns. This is useful but not yet an
integratable result: only 96 of the device's 4400 slices are unoccupied in the
stock Pluto placement, and the core still lacks its I/Q conversion and adapter.

The next RTL revision therefore keeps the bit-exact arithmetic while adding a
pipeline and synchronous table reads. Resource acceptance is based on a full
Pluto route, not on the standalone LUT count alone.

## Recheck the imported VHDL

```powershell
.\run-reference-sim.ps1
.\run-reference-synth.ps1
```

These scripts use Vivado 2026.1 XSIM and synthesis. They do not require Pluto
hardware and do not alter the device.

## Implemented Pluto image result

The separate CPM-H image completed synthesis, placement, routing, DRC and
bitstream generation in Vivado 2026.1. Post-route timing passed with +0.994 ns
setup slack and +0.022 ns hold slack. The complete image uses:

- 4317/4400 slices (98.11%);
- 11588/17600 LUTs (65.84%);
- 18976/35200 registers (53.91%);
- 3.5/60 BRAM tiles (5.83%);
- 72/80 DSP48E1 blocks (90.00%).

The entire `pn15_tx` hierarchy uses 358 LUTs, 163 registers, three RAMB18
blocks and zero DSP blocks. Its `cpm_h_tx_core` accounts for 324 LUTs and 127
registers. The custom modulator is therefore not responsible for the high DSP
use.

The 72 DSP blocks in the complete image are distributed as follows:

- 22 in the two receive FIR decimators (11 each);
- 22 in the two transmit FIR interpolators (11 each);
- 28 in the stock AD9361 interface: 12 in its four receive channels and 16 in
  its four transmit channels.

The current image deliberately retains the stock DMA path, both RF channels,
and the complete receive path so that TX1-to-RX2 cable-loopback testing remains
available. The most useful future size variants are:

1. A dedicated CPM-H transmitter can remove the unused DMA fallback and the
   transmit FIR pair, recovering 22 DSPs plus roughly 900 LUTs and more than
   2400 registers across the FIR and DMA hierarchy.
2. A 1R1T build, tested with TX1 connected to RX1, can eliminate the second RF
   channel datapaths. This saves 14 AD9361-interface DSPs and several thousand
   LUT/register resources while retaining loopback capture.
3. Removing the receive FIR pair saves another 22 DSPs, but changes the receive
   sample-rate/filtering path and should only be done in a purpose-built
   transmit-only image.

The BRAM sine table and small source FIFO should remain. BRAM use is low, and
replacing these memories with logic would make the actual constraint—slice
packing—worse.

Build artifacts and the detailed hierarchical utilization report are under
`plutoplus-vivado2026/artifacts/cpm-h-postfir/`. The FPGA-manager loadable file
is `pluto_cpm_h.bit.bin`.

