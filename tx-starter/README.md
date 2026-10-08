# Pluto TX workflow starter

**Current status (2026-10-08):** the VHDL source, sample-request adapter and
control wrapper are integrated and hardware-tested in the sibling
`../plutoplus-vivado2026` project. See [workspace results](../README.md).
The sections below retain the standalone starter's development history;
references to missing Zynq support or pending integration are superseded.

Goal: prove a custom FPGA transmit path before returning to CPM. This is a
platform-independent RTL source, not yet a Pluto firmware image.

## VHDL version — current development entry point

The self-contained VHDL source is in `vhdl/`:

- `pn15_generator.vhd`: 15-bit PN sequence with seed, restart and advance.
- `bpsk_mapper.vhd`: bit -> signed I/Q mapping.
- `pn15_bpsk_tx.vhd`: top level, sample repetition and ready/valid flow control.

Run `./pluto-dev/tx-starter/run-vhdl-sim.ps1` from the workspace root.
The VHDL-2008 testbench is `sim/pn15_bpsk_vhdl_tb.vhd`. It uses the independent
Python reference vectors and passed **65663 samples at SPS=1** and **525297
samples at SPS=8**, including both seeds, full-period wraparound, stalls,
enable pauses, restart and zero-seed recovery. Results are in
`build/vhdl-sim/xsim-vhdl.log`.

Run `./pluto-dev/tx-starter/create-vivado-project.ps1` to create the browsable
`build/vivado-vhdl/tx_vhdl_core.xpr` project and synthesize the standalone core.
This project contains only the VHDL implementation; the SystemVerilog version
below remains an independent earlier implementation and is not compiled into it.
The installed Vivado lacks xc7z010clg400-1, so the script explicitly selects an
available fallback part for isolated core work. `TARGET.txt` records that choice.
The project/checkpoint is **not a programmable Pluto board image** and has no
board pin constraints or timing sign-off.

Standalone synthesis completed successfully on 2026-10-01 using fallback part
xc7vx485tffg1157-1: **24 LUTs, 19 flip-flops, no BRAM or DSP blocks** for the
default SPS=8 core. There were no errors or critical warnings. The 31 warnings
are constant output bits, expected for the two fixed BPSK amplitudes and Q=0.
No clock constraints, placement/routing, or board timing checks were performed.
Report: `build/vivado-vhdl/core-utilization.rpt`.

For the actual Pluto+ source baseline, TX connections and remaining hardware
work, see [PLUTO-INTEGRATION.md](PLUTO-INTEGRATION.md).

## Implemented and tested

`rtl/pn15_bpsk_tx.sv` generates PN15 inside the FPGA and reuses the existing
`rfnoc-dev/rfnoc-bpsk/rfnoc/fpga/bpsk/rfnoc_block_bpsk/bpsk_mapper.sv` DSP module.
It does not instantiate RFNoC or depend on UHD hardware.

Signal path: PN15 -> BPSK -> repeated samples -> ready/valid output.

- Polynomial convention: b[n+15] = b[n+14] XOR b[n], x^15+x^14+1.
- State[0] is output; shift right, feedback state[14] XOR state[0] into bit 14.
- Default test seed: 0x7fff. Seed is sampled on synchronous reset/restart.
- Seed zero is replaced with 0x7fff, avoiding the locked zero state.
- Output: signed 16-bit I = -16384 or +16384, Q = 0, packed {I,Q}.
- SAMPLES_PER_SYMBOL is a build-time positive integer (default 8).
- A symbol advances after that many accepted samples, not FPGA clock cycles.
- Symbol rate = accepted output sample rate / SAMPLES_PER_SYMBOL.
- Enable low stops offering new samples; an already offered sample completes
  normally, preserving ready/valid behavior. Re-enable resumes the sequence.
- Reset/restart flushes pending output and resets the sequence and sample phase.
  The downstream consumer must be coordinated with these explicit resets.
- Seed/enable/restart must be synchronous to clk. These are HDL ports, not yet
  ARM-accessible registers. Add a register interface and clock crossings during
  board integration.
- Repetition is rectangular symbol shaping. No RRC/FIR filter is included yet.
  This source is continuous and has no packet framing or tlast.

## Run the offline test

In PowerShell: `./pluto-dev/tx-starter/run-sim.ps1` from the workspace root.
Uses the existing local Python environment and Vivado/XSim 2026.1.

Verified 2026-10-01:

- Independent Python bit recurrence checks 32767 distinct nonzero states,
  return to the seed, and 16384 ones per period for two different seeds.
- HDL simulation at SPS=1: **65663 accepted samples passed**.
- HDL simulation at SPS=8: **525297 accepted samples passed**.
- Both seeds tested for a full period plus wraparound, with random stalls.
- Checked enable pauses, output stability while stalled, explicit restart,
  zero-seed recovery, signed amplitude, Q=0, and sample repetition.
- Logs: `build/sim/xsim-sps1.log`, `build/sim/xsim-sps8.log`.

This verifies the RTL source; it does not establish actual RF transmission.

## Hardware workflow still to prove

1. Confirm the physical Pluto+ variant/FPGA and find its matching board sources.
2. Build the unchanged board reference with the matching toolchain.
3. Add the source to the TX path, with sample-clock/request adaptation, correct
   ADI DAC sample ordering/scaling, and a selection control that defaults to the
   original path. The generic ready/valid core cannot be wired blindly to DAC pins.
4. Simulate the integrated interface and check timing/utilization in implementation.
5. Produce a compatible image and validate loading/recovery before persistent flashing.
6. Verify the TX waveform with suitable receive/measurement equipment and agreed
   RF settings. No TX frequency or antenna setup has been selected here.

The published Pluto+ repository has been cloned to `../plutoplus-reference`.
Its pinned firmware and HDL submodules have been fetched; both select Vivado
**2019.1** as their tested baseline. Migration to installed 2026.1 can be attempted;
the HDL version guard has an override, but IP and SDK/HDF scripts need checking.
The user confirmed XC7Z010/CLG400, matching the reference device/package.
PCB pinout and speed grade still need confirmation. The board HDL patch passes
an application dry-run, but no patches have been applied. Linux and bootloader
submodules have not been fetched.

No firmware was flashed, no running FPGA image was replaced, and no RF TX was
started by this task. Existing RFNoC work and the user's serial terminal are intact.
