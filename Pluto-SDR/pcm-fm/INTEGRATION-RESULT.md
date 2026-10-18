> Hardware update, 2026-10-18: the selector was moved after the stock TX
> interpolator. Selector 0 now preserves the verified DMA path, and selector 1
> produces received PN15 PCM-FM in the attenuated loopback test.

# Integrated PCM-FM Pluto build

Status verified 2026-10-09: adapter XSIM passed and the full XC7Z010 Pluto image
passed the inherited build's setup, hold, pulse-width and DRC gates. The PCM-FM
image has NOT been loaded onto the board or tested over RF.

## Final integrated resources

| Resource | Used | Capacity | Remaining |
|---|---:|---:|---:|
| LUTs | 11965 | 17600 | 5635 |
| Registers | 19561 | 35200 | 15639 |
| Block RAM tiles | 6.5 | 60 | 53.5 |
| DSP slices | 74 | 80 | 6 |

Compared with the verified BPSK image: +703 LUTs, +725 registers, +4.5 BRAM tiles,
+2 DSP slices. This is an integrated measurement, replacing the standalone sum
estimate. DSP capacity is the tightest resource.

Setup slack +0.910 ns; hold +0.014 ns; pulse width +0.264 ns. Zero failing
endpoints in those categories and zero DRC errors. The original board clocks
and constraints are used; the 100 MHz standalone test target is not substituted
for the actual integrated clocks. The standalone boundary hold failures are
absent in this complete implementation.

## Simulation and interface

The core and the source adapter each passed 268280 exact reference comparisons.
The adapter supports one request per clock and gaps using a 32-word FIFO with
16-word startup prefill. PN15 bits are held for eight output samples. See
[adapter contract](PLUTO-ADAPTER.md) and [test evidence](results/ADAPTER-XSIM-RESULT.md).
GPIO 0x41210000 bit 0 selects DMA (0) or PCM-FM (1). Channel names pn15_tx and
pn15_control remain in the block design to preserve the audited CDC selectors.
The two-flop selector is reported CDC-3 with ASYNC_REG.

## Project and artifacts

- Project: `../plutoplus-vivado2026/build/pcm-fm-postfir/pluto_pcm_fm.xpr`
- Artifacts: `../plutoplus-vivado2026/artifacts/pcm-fm-postfir/`
- `.bit`: Vivado bitstream; `.bin`: raw export.
- `.bit.bin`: Bootgen-converted Linux FPGA-manager payload for a later volatile load.
- `.xsa`: hardware platform with matching bitstream; `.dcp`: routed checkpoint.
- Reports: timing, utilization, CDC, methodology, exceptions and DRC.
- `sha256.json`: artifact hashes; verifier checks the BIT/BIN/XSA payload match,
  passing timing, and exact byte-order/padding transformation for FPGA manager.

Reproduce with `../plutoplus-vivado2026/run-pcm-fm-build.ps1`. Creation refuses
to overwrite an existing PCM-FM project; use `-BuildOnly` for rebuilding that
project. The earlier BPSK project and hardware results remain separate.

## Remaining limits and next action

Inherited CDC reports remain: 54 CDC-1 and 12 CDC-13 critical entries, matching
the earlier BPSK counts. Methodology also reports TIMING-54 and 36 missing I/O
delays. Passing the stated timing gates is not proof of complete CDC correctness,
fully constrained board interfaces, or IRIG RF spectral compliance. The physical
speed grade remains assumed -1, as in the previous verified Pluto build.

Hardware verification used TX1 -> 30 dB attenuator -> RX2 at 915 MHz and
2.5 MS/s. Selector-0 DMA produced a 915.100098 MHz tone at -33.14 dBFS.
Selector-1 PN15 PCM-FM raised RX RMS to 64.144 counts with -28.33 dBFS power
inside +/-500 kHz. The bounded verification ended with TX muted, selector 0,
and the TX buffer disabled. Spectral-mask compliance and production data input
remain future work.
