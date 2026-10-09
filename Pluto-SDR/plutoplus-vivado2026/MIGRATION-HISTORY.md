# Pluto+ migration to Vivado 2026.1

Hardware milestone, 2026-10-08: the PN15 FPGA image was temporarily loaded and
tested on TX1 → 30 dB attenuator → RX2. Zero mismatches in 126975 analyzed PN15
symbols at 312500 symbols/s, including 118783 held-out symbols. USB and drivers
recovered using the repaired detached loader. TX is disabled and flash unchanged.
See ../captures/pn15-hardware-20261008-183726/RESULT.md. Older status below is history.

Latest result: the baseline implemented checkpoint passes full timing analysis
with corrected legacy DMA CDC constraints. Setup and hold slack are +0.018 ns;
no failing timing endpoints or DRC errors. Bitstream, binary, checkpoint and XSA
were exported under `artifacts/baseline`, with SHA-256 hashes. The XSA's embedded
bitstream payload matches the exported binary. See `TIMING-CLOSURE.md` for the
fix, reproduction steps and remaining I/O/CDC warnings. No hardware was flashed;
the custom PN15 transmitter is now integrated in a separate project and its
2026-10-03 implementation passed full timing and DRC error checks. Earlier sections below record
the migration history.

## PN15/BPSK project (2026-10-02)

Validated 2026-10-03: setup slack +0.854 ns, hold +0.019 ns, pulse width
+0.264 ns; zero failing endpoints and zero DRC errors. Final usage is
11262/17600 LUTs, 18836/35200 registers, 2/60 BRAM tiles and 72/80 DSPs.
The added design costs 106 LUTs and 60 registers relative to the baseline.
Legacy CDC critical counts remain 54 CDC-1 and 12 CDC-13; the new control
crossing is recognized as a two-stage ASYNC_REG synchronizer (CDC-3).
Missing I/O delays and legacy methodology warnings remain; timing pass is
not proof of complete CDC correctness, board compatibility or RF behavior.

The prior failure came from Tcl control flow inside XDC, rejected by read_xdc.
The board XDC now contains flat commands for 21 nonempty target groups.
The pre-optimization and post-route Tcl audit fails if a retained selector
goes missing. See logs/count-pn15-cdc-console.txt for all 30 original targets.
Nine absent groups were removed for this fixed configuration. The rebuild
used `build-pn15.tcl -reuse-synth`; RTL was unchanged. No blanket false paths
or clock-period changes were added to resolve the failure.

Artifacts are in `artifacts/pn15`: .bit, raw .bin, .dcp, .xsa, reports and
SHA-256 manifest. `pluto_pn15.bit.bin` is the Bootgen-processed FPGA Manager
file, verified as word-swapped raw payload plus one padding NOP. It is not
a .frm firmware updater. See ../PLUTO-LOAD-PLAN.md; hardware loading remains
unperformed.

Open `build/pn15/pluto_pn15.xpr`. `integrate-pn15.tcl` created this separate
project from the baseline and inserted the VHDL `pn15_tx` module ahead of the
channel-0 TX interpolator. Its default path passes the existing DMA I/Q data.
The one-bit AXI GPIO `pn15_control` at base address `0x41210000` selects PN15
when bit 0 is one. Selection crosses through two sample-clock synchronizer
registers; deselection resets the PN sequence. Both I and Q must be enabled.
The current source repeats each symbol for eight accepted samples and maps
bit 0 to I=-16384, bit 1 to I=+16384, with Q=0.

`build-pn15.tcl` runs synthesis, implementation, full timing and DRC checks,
then exports into `artifacts/pn15`. Consult its current log in
`logs/build-pn15-console.txt` before treating those artifacts as validated.
No PN15 bitstream has been loaded onto the device or verified over RF.

The standalone adapter and selection-wrapper simulations are in
`../tx-starter/build/adapter-sim`. The debug snapshot `pluto_tx_top_view` and
`pn15_bpsk_view.wcfg` show the first 10 microseconds of the wrapper test in
XSIM. These simulations do not model the complete AD9361 or analogue RF path.

This is an isolated working copy. The checkout under `../plutoplus-reference` is preserved.

## Provenance

- ADI HDL commit: `061d024d596ef84c6a819854bf2472e6b43a2d5d`.
- Pluto+ reference commit: `2d30d36aabc1ba4e7a5982d8548a8e44551218c1`.
- Applied the reference repository's `patches/hdl.diff` to this copy only.
- Board target: `xc7z010clg400-1`, including the official Pluto+ pin and processing-system changes. User confirmed XC7Z010 and CLG400 markings; speed grade and exact PCB revision remain to be independently checked before programming.
- Reference scripts expect Vivado 2019.1. These launchers explicitly enable ADI's version override for the 2026.1 migration; this is not a claim of full compatibility.

## Build stages

From this directory in PowerShell:

```powershell
./run-build.ps1 -Stage PackageIp
./run-build.ps1 -Stage Baseline
```

The first stage packages util_cdc, util_axis_fifo, axi_dmac, axi_ad9361, util_cpack2 and util_upack2 in dependency order. The second invokes the patched reference board build. It refuses to substitute another FPGA if the target is missing. Logs are under `logs/`.

## Verified on 2026-10-01

All six IP packages were generated with Vivado 2026.1 and the packaging process exited successfully. The log contains version mismatch, interface inference, source packaging and long-path warnings. Packaging success alone does not validate block-design integration, timing, or hardware behavior.

Zynq-7000 device support was absent when work began. AMD's installer has been opened for adding it. Re-run PackageIp after installing device support: the legacy packaging scripts derive supported families from the installed parts.

No complete board bitstream or flashable firmware has been produced. No device programming has been performed. The standalone PN15/BPSK VHDL core and its passing simulations are in `../tx-starter`; it has not yet been inserted into this baseline.

## Next validation

1. Finish adding Zynq-7000 support, then repackage the libraries.
2. Build and repair the baseline reference design under 2026.1, addressing actual migration errors. The old HDF/SDK export may require replacement with an XSA export.
3. Integrate the PN15/BPSK VHDL source with a sample-request adapter into the AD9361 TX path, preserving a bypass path, and simulate the adapter before building.
4. Validate the target board and produce the appropriate loadable artifact. RF output and firmware compatibility require the physical board; RTL simulation and synthesis do not.

## Installation verification update
Vivado 2026.1 now resolves xc7z010clg400-1. All six library packages were regenerated successfully after the Zynq installation; axi_ad9361 metadata now includes zynq. The baseline retry has passed the previous unsupported-part error and is constructing the board design. Full build completion remains unverified.


## CDC packaging migration repair
The first board synthesis failed because Vivado 2026.1 omitted sync_event.v from the util_cdc subcore. Adding it as a loose board source was automatically disabled by hierarchy analysis. The durable fix in hdl/library/util_cdc/util_cdc_ip.tcl explicitly retains sync_event.v and sync_gray.v in both synthesis and simulation file groups. Repackaging succeeded and both files are verified in component.xml. A fresh baseline build is running; synthesis/timing success is still pending.


## Baseline synthesis result
After the CDC packaging correction, full XC7Z010 baseline synthesis passed with zero errors. Synthesis reports 13718/17600 LUTs, 19218/35200 registers, 72/80 DSPs and 2/60 block RAM tiles. Implementation is running. The log retains warnings, including duplicate sync_bits definitions; no routed timing pass is claimed yet.

