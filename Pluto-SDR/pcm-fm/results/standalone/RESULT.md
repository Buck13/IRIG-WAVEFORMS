# Standalone XC7Z010 implementation check

Vivado 2026.1, xc7z010clg400-1, 100 MHz engineering target. Synthesis,
optimization, placement and routing completed. No Pluto image was modified.

| Resource | Routed core | Existing BPSK image | Simple sum | Device capacity |
|---|---:|---:|---:|---:|
| LUTs | 692 | 11262 | 11954 | 17600 |
| Registers | 737 | 18836 | 19573 | 35200 |
| Block RAM tiles (36 Kb) | 4 | 2 | 6 | 60 |
| DSP slices | 2 | 72 | 74 | 80 |

The sums are planning estimates, not integrated-build measurements. They retain
the existing BPSK image and omit any new wrapper/control logic; optimization
and debug-port removal may change the eventual counts. Six DSP slices remain
under this estimate. Synthesis before physical optimization reported 699 LUTs;
the other listed core counts were unchanged after routing.

## Timing: internal paths pass; complete timing is NOT closed

- Overall setup slack: +3.281 ns; zero failing setup endpoints.
- Internal register-to-register hold slack: +0.109 ns.
- Overall hold slack: -0.317 ns, 821 failing endpoints.
- Checkpoint query classified all 821 failing hold paths as starting at input
  ports, with zero other startpoints. Worst path starts at reset.
- Pulse-width slack: +4.500 ns.

Standalone constraints specify 2 ns maximum and 0 ns minimum interface delays.
These are explicit engineering assumptions, not measured Pluto interface timing.
Vivado warns that HD.CLK_SRC and input HD.PARTPIN_LOCS are absent: this standalone
block has no final clock source or interface placement, so boundary timing and
clock skew are not representative of the integrated design. No false paths or
relaxed delays were added to hide the failures. The next integration must provide
the actual clock and synchronous interface registers, then rerun full timing.

DRC reports zero errors and five warnings: two DSP output-pipeline warnings,
two DSP multiplier-pipeline warnings, and missing PS7 in the isolated block.
Synthesis also warned about the large declared tree array; unused/zero logic
was trimmed to the measured resource totals. No claim of bitstream readiness.

## Reproduce

Run `./run-standalone.ps1`. To classify hold paths, run Vivado batch with
`inspect-standalone.tcl` after implementation. Reports are preserved here;
local synthesized/routed checkpoints are under `build/standalone/`.

Next: add the PN15/sample-rate wrapper and latency-aware Pluto TX adapter,
verify that interface in XSIM, then implement the full Pluto design.
