# Imported CPM-H reference baseline

Validated with Vivado 2026.1 on 2026-10-20.

## Functional simulation

The imported VHDL-2008 core, ROM package and original vectors compiled in XSIM
and passed all 6000 vectors. This independently reproduces the earlier GHDL
result after transfer into the Pluto repository.

## Standalone XC7Z010 synthesis

Target `xc7z010clg400-1`, 100 MHz constraint:

| Resource | Used |
|---|---:|
| LUT | 306 |
| Registers | 91 |
| BRAM tiles | 0 |
| DSP48E1 | 0 |
| WNS | -1.944 ns |

Vivado mapped the three 32-entry pulse sections into LUT ROM and constant
arithmetic into LUT/carry logic. The result does not consume the six DSP blocks
left by the PCM-FM image, but the single-cycle path does not meet 100 MHz.

This measurement covers only the phase core. It excludes the sine/cosine I/Q
table, continuous-sample adapter, PN/data source, control registers and the
complete Pluto placement/routing pressure.
