# Post-interpolator PCM-FM hardware result

Verified on 2026-10-18 using Pluto+ TX1 -> 30 dB attenuator -> RX2, 915 MHz,
2.5 MS/s, 1 MHz RF bandwidth, TX gain -30 dB and RX2 manual gain 30 dB.

The unmodified local Vivado baseline first reproduced a 100 kHz DMA tone,
proving the Vivado 2026.1 build and volatile loading path. The earlier custom
images failed because their selector was inserted before the TX interpolator.

The corrected image inserts the selector after the stock interpolator:

- Selector 0 DMA tone: 915.100098 MHz, -33.14 dBFS peak, RX RMS 47.117 counts.
- Selector 1 PN15 PCM-FM: RX RMS 64.144 counts, -60.89 dBFS peak and
  -28.33 dBFS integrated power inside +/-500 kHz.
- FPGA Manager payload SHA-256:
  `63c4d5061893a088a3cff482bcc4bcb2afd24fd773902518b0ea24bed926bc11`.

The test used a device-side 12-second watchdog and explicit cleanup. Final
state was TX gain -89.75 dB, selector 0 and TX buffer disabled. The FPGA load
was volatile; flash was not modified.
