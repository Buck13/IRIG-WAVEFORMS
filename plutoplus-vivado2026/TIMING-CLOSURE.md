# Pluto+ baseline timing closure — 2026-10-01

Target: XC7Z010 CLG400 -1, Vivado 2026.1. This is the baseline Pluto+ radio design; the PN15/BPSK transmitter is not integrated yet.

## Result

The complete implemented-design timing analysis meets all user-specified timing constraints:

- Worst setup slack: +0.018 ns; zero failing endpoints.
- Worst hold slack: +0.018 ns; zero failing endpoints.
- Worst pulse-width slack: +0.264 ns; zero failing endpoints.
- Separate searches for negative setup and hold paths found none.
- Design-rule checking reported no errors; warnings remain.

Reports and hardware artifacts are in `artifacts/baseline`. These results apply to that implementation checkpoint. Any new integration or implementation must be checked again; 18 ps is a narrow margin.

## What changed

1. Implementation uses Performance_Explore, AggressiveFanoutOpt and post-route physical optimisation. This corrected the original 24 ordinary setup failures, including control-register fanout paths with -1.605 ns worst slack.
2. `hdl/projects/pluto/dma_metadata_cdc.xdc` restores specific legacy DMA crossing constraints at board scope. Vivado 2026.1's inferred metadata RAM names and scoped constraint matching left several paths without their intended exceptions. Selectors now address the actual metadata RAM primitives, held FIFO data registers and first synchroniser stages.
3. Delay bounds retain the original `axi_dmac_constr.ttcl` intent: launch-clock period for synchronised pointers/IDs, destination-clock period for handshake-protected metadata. No blanket asynchronous clock-group exception, clock reduction, or arbitrary multicycle path was used.
4. The legacy HDF export was migrated to XSA. Export refuses to proceed if full timing or DRC error checks fail.

The first routed summary used Vivado's `-routable_nets` filter and did not expose all cross-clock problems. The accepted result uses an unfiltered timing summary and explicit negative-path queries.

## Reproduction

- `run-build.ps1 -Stage Baseline` includes the new late implementation constraints and optimisation settings.
- `improve-timing.tcl` re-runs implementation from the existing synthesis result with those settings.
- `validate-cdc-fix.tcl` audits the saved post-route checkpoint with the corrected constraints.
- `export-validated-baseline.tcl` checks the implemented checkpoint with the corrected constraints and exports reports, checkpoint, bitstream, binary and XSA.

The accepted snapshot was validated after applying the corrected constraints to the routed implementation. A fresh end-to-end build with the new constraints active during placement/routing has not yet been performed; its result may differ.

## Limits

The reference constraints still leave 16 inputs and 20 outputs without I/O delay specifications. The detailed timing, methodology and CDC reports retain these and other legacy warnings. Timing closure under these constraints is not a claim of complete board-level I/O or CDC certification.

The speed grade and exact Pluto+ PCB revision have not been independently confirmed. No hardware was programmed. The `.bit`/`.bin` files are FPGA artifacts, not a complete USB firmware-update package. Firmware compatibility and RF behaviour remain to be tested on the board.
