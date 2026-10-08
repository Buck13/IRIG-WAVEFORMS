# Stock Pluto TX1 to RX2 loopback — 2026-10-08

Passed a bounded stock-firmware tone test through the user-confirmed TX1 →
30 dB attenuator → RX2 cable. Both RX channels were captured simultaneously.
Internal loopback was disabled. This does not test the custom PN15 FPGA image.

Settings: 915 MHz TX/RX LO, 2.5 MS/s, 1 MHz analogue bandwidth, manual
30 dB RX gain, 40 dB TX1 attenuation, DDS scale 0.125. TX2 stayed at 89.75 dB
attenuation with its DDS scales zero. Frequency and gain settings remain
configured; the tone is disabled after testing.

| Capture | RX2 dominant frequency | RX2 RMS, ADC counts | Clipped components |
|---|---:|---:|---:|
| Before tone | noise | 2.35 | 0 |
| 200 kHz tone | 199991.86 Hz | 5.23 | 0 |
| 350 kHz tone | 349985.76 Hz | 5.06 | 0 |
| After tone disabled | noise | 2.38 | 0 |

FFT bin spacing for the numeric peak estimates is approximately 25.43 Hz.
Both frequencies are within one bin of the commanded value. RX1 remained
near 2 ADC counts RMS. Peak-over-median-bin values in results.json are spectral
contrast, not integrated SNR or calibrated RF power.

Each binary contains 131072 frames of four interleaved little-endian signed
16-bit containers: RX1 I, RX1 Q, RX2 I, RX2 Q. Samples carry signed 12-bit
data. The first 32768 frames were excluded from analysis.

Independent final readback: DDS raw=0; TX1 and TX2 hardwaregain=-89.750000 dB.
No FPGA programming, flash write or driver unloading occurred in this test.
