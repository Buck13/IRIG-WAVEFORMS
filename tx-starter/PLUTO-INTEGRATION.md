# Pluto+ integration findings

The physical FPGA marking supplied by the user is XC7Z010, CLG400ABX2409.
That confirms the device/package, not the speed grade or PCB revision. The
published Pluto+ reference selects xc7z010clg400-1 and changes many board pins.
Confirm the board revision/pinout before programming a board image.

## Source baseline inspected

- Pluto+ repository: 2d30d36aabc1ba4e7a5982d8548a8e44551218c1.
- Firmware submodule: d38242e8bd740ea8fc35cc4fe7436401b39905f2.
- HDL submodule: 061d024d596ef84c6a819854bf2472e6b43a2d5d.
- Official Pluto+ patches/hdl.diff passes `git apply --check` against that HDL.
  It has not been applied; the reference checkout remains unchanged.
- Both the firmware Makefile and pinned ADI HDL scripts select Vivado 2019.1
  as their tested baseline. The HDL version guard can be overridden with
  ADI_IGNORE_VERSION_CHECK=1. This permits a migration attempt; it does not prove
  the board design builds correctly in 2026.1. The firmware build also uses old
  SDK/HDF commands (xsdk and system_top.hdf), which may need migration separately.
  Installed 2026.1 has passed isolated-core validation; board validation is pending.

## TX path in the pinned HDL

See `../plutoplus-reference/plutosdr-fw/hdl/projects/pluto/system_bd.tcl`.

    ARM/DDR -> axi_ad9361_dac_dma -> tx_upack
            -> tx_fir_interpolator -> axi_ad9361 -> RF transceiver

For channel 0, tx_upack/fifo_rd_data_0 and _1 feed
tx_fir_interpolator/data_in_0 and _1. These correspond to I0 and Q0.
The FIR's data_out_0 and _1 feed axi_ad9361/dac_data_i0 and dac_data_q0.
The common sample-domain clock is axi_ad9361/l_clk; the reference uses
axi_ad9361/rst for sample-domain resets.

The intended insertion point is a selectable PN/BPSK source ahead of the FIR.
It must keep the original DMA path available and selected by default. Selection,
enable and seed controls will need clock-domain-safe ARM register access.
The FIR's valid_out_0 is a sample-request signal toward the existing unpacker;
it must be adapted and simulated, not assumed to be a generic AXI ready signal.
Channel enable and I/Q request alignment must also be accounted for.

The VHDL core word is {I,Q}; connect bits 31:16 to I and 15:0 to Q. Do not assume
this matches a 32-bit packed bus in the ADI design, where ordering can differ.
The pinned axi_ad9361_tx_channel.v selects dma_data[15:4] for its 12-bit sample
path. Thus our +/-16384 in a 16-bit input corresponds to +/-1024 at that mux,
before further radio processing. This is not an RF-power calibration.

The reference already contains an interpolator. Our SAMPLES_PER_SYMBOL repeats
samples upstream of it; it does not replace the reference interpolation factor.
Final symbol rate depends on the configured radio/FIR sample rates and this
repetition factor. No radio rate, LO frequency or gain has been programmed here.

## Remaining board work

1. Match PCB pinout and speed-grade assumptions and add XC7Z010-CLG400 device
   support. Attempt the board baseline in a separate working copy using current
   Vivado with deliberate IP/script migration, or use the tested 2019.1 toolchain.
2. Implement/test a source-select and sample-request adapter with clock/reset
   handling and ARM controls. These are not included in the standalone VHDL core.
3. Integrate, implement, check timing/resources and produce a compatible firmware
   package. Do not load the standalone core synthesis checkpoint as board firmware.
4. Validate loading and TX measurement on the actual board.

The VHDL project demonstrates the core design workflow; the full USB-to-custom-
FPGA-to-RF workflow is still pending these board-integration steps.

## Sample-request adapter implemented
The VHDL pluto_pn15_tx_adapter now captures a PN/BPSK sample on each enabled request edge and presents it after that edge, matching util_upack2's registered output convention. DMA bypass is combinational and adds no delay. Deselecting PN resets its sequence; disable mutes its registered output; restart reloads the seed. Controls must already be synchronous to the sample clock. Allow one priming clock before requesting after selection or restart. The module is not yet connected to the board design and ARM control CDC remains pending.
run-adapter-sim.ps1 passed a complete 32767-symbol period at eight samples per symbol, varying request gaps, wrap, bypass, disable and restart against the independent Python reference. This verifies the adapter in isolation, not complete radio timing or RF output.


The source plus adapter also passed out-of-context synthesis for xc7z010clg400-1: 59 LUTs, 22 registers, zero DSPs and zero block RAM. See build/adapter-synth/utilization.rpt. This is an isolated resource estimate, not routed board timing; the 10 ns clock in synth-adapter.tcl is an analysis constraint.

