# Custom FPGA PN15/BPSK hardware result — 2026-10-08

The custom FPGA image was successfully loaded through Linux FPGA Manager.
The detached loader muted TX, unbound consumers/providers, loaded the verified
binary, rebound drivers, restarted IIO in the background and rebound USB.
`../../pn15-load-success.txt` records completion and the radio drivers returned.
No flash writes occurred. A power cycle restores the boot firmware image.

TX1 → external 30 dB attenuator → RX2, user-confirmed connection.
LO: 915 MHz both directions; sample rate: 2.5 MS/s; analogue bandwidth:
1 MHz; manual RX gain: 30 dB; TX1 attenuation during capture: 40 dB.
TX2 remained maximally attenuated. Internal radio loopback was disabled during
the preceding stock test and no command enabled it in this test.

The host supplied an all-zero cyclic DMA buffer to enable the TX data path.
All PN15 data and BPSK mapping came from the custom FPGA source. GPIO register
0x41210000 selected that source only for the middle capture.

| State | RX2 RMS (ADC counts) | Clipped components |
|---|---:|---:|
| DMA zero / PN disabled | 2.56 | 0 |
| FPGA PN15 enabled | 20.25 | 0 |
| FPGA PN15 disabled again | 2.59 | 0 |

PN15 comparison used the RTL recurrence b[n+15]=b[n+14] XOR b[n], seed all
ones. Timing, circular sequence offset and constant complex phase were fitted
using 8192 symbols. The chosen rate was eight samples/symbol (312500 symbols/s)
and normalized correlation was 0.997798. Decisions were then checked against
the reference with that alignment fixed: zero mismatches in 118783 held-out
symbols, and zero in all 126975 analyzed symbols (over three PN15 periods).
This is a finite shared-device cable-loopback test, not a BER guarantee or an
independent-carrier receiver synchronization test. No measured RF power is claimed.

Each raw capture contains 1048576 frames of little-endian signed 16-bit
containers ordered RX1 I, RX1 Q, RX2 I, RX2 Q (12-bit ADC values). The first
32768 frames were excluded. See pn15-analysis.json and pn15-result.png.

Final independent hardware readback: source-select=0, DDS raw=0, TX1 and TX2
hardwaregain=-89.750000 dB, FPGA Manager=operating. Custom image remains loaded
in volatile FPGA configuration; PN generation is deselected and RF TX muted.
