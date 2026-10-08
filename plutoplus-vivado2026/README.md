# Pluto+ Vivado 2026.1 implementation

Current status: **built, timing-checked, temporarily loaded and tested on hardware**.
See the [workspace README](../README.md) for the complete progress record.

## Verified results

- Target: xc7z010clg400-1, Vivado 2026.1.
- Full routed PN15 timing: setup +0.854 ns, hold +0.019 ns, pulse width +0.264 ns.
- Zero failing timing endpoints and zero DRC errors.
- Resources: 11262 LUTs, 18836 registers, 2 BRAM tiles, 72 DSP slices.
- On 2026-10-08, the FPGA PN15/BPSK source passed TX1 → 30 dB attenuator → RX2
  testing: 126975 checked symbols, zero observed mismatches at 312500 symbols/s.
- PN source and DDS were disabled afterward, with both TX gains at -89.75 dB.
- FPGA loading was temporary. Flash was unchanged.

## Files and reproduction

`run-build.ps1 -Stage PackageIp` packages the six required ADI IP libraries.
`run-build.ps1 -Stage Baseline` builds the board baseline. `integrate-pn15.tcl`
creates the separate custom project; `build-pn15.tcl` builds and checks it.
Use `-tclargs -reuse-synth` only when RTL is unchanged and synthesis is complete.

The project is `build/pn15/pluto_pn15.xpr`. Exported .bit, .bin, .dcp and .xsa
files are under `artifacts/pn15`, alongside committed reports and SHA-256 hashes.
Generated projects and binaries are local, untracked outputs.

`verify-pn15-artifacts.py` checks full timing, BIT/BIN/XSA payload agreement and
Bootgen conversion. `fpga-manager.bif` in the artifact directory describes the
Bootgen input. The resulting `pluto_pn15.bit.bin` is for FPGA Manager, not the
USB firmware-update drive.

The checked-out ADI HDL source is based on commit
`061d024d596ef84c6a819854bf2472e6b43a2d5d`; our committed migration is
`c00f4a550360781013c15b0373709e805946f087`. Its complete patch is tracked at
`../patches/adi-hdl-plutoplus-vivado2026.patch`.

## Integration

The VHDL block precedes the channel-0 TX interpolator. AXI GPIO at 0x41210000
selects PN15 with bit 0=1, or original DMA I/Q with bit 0=0 (reset default).
Selection uses a two-register clock crossing. Both I/Q enables must be asserted.
Each symbol occupies eight accepted samples; I is +/-16384 and Q is zero.

## Remaining limits

Legacy CDC critical reports (54 CDC-1, 12 CDC-13), missing I/O delays and scoped
constraint warnings remain. The new select crossing is recognized as CDC-3.
Physical speed grade was not independently verified. The successful cabled
loopback is not an independent RF conformance or long-duration BER test.

[Hardware evidence](../captures/pn15-hardware-20261008-183726/RESULT.md),
[loading procedure](../PLUTO-LOAD-PLAN.md), [timing investigation](TIMING-CLOSURE.md)
and [historical migration notes](MIGRATION-HISTORY.md) retain the detailed record.
Historical notes describe intermediate failures and superseded status statements.
