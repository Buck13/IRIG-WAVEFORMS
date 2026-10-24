# Automatic CPM-H RX loopback result

## Result

The Pluto Plus XC7Z010 image completed a real RF loopback test using:

- TX1 -> 30 dB attenuator -> RX2;
- 915 MHz center frequency;
- 8 MS/s converter rate and 3 MHz RF bandwidth;
- 32 samples per dibit, producing 500 kbit/s;
- -30 dB TX hardware gain and 30 dB RX2 gain;
- host DMA PN15 ARTM CPM-H stimulus;
- FPGA correlation-bank Viterbi detector and PN15 recurrence scorer.

Five consecutive searches of all 32 timing offsets and four starting epochs
each found a hypothesis with 0 errors in 64 checked PN15 bits. The receiver
reported `dropped=0` and `overflow=0`.

At 16 MS/s and 1 Mbit/s the detector asserted `dropped=1` and produced
random-like PN15 scores. The 200-clock dibit interval at that rate does not
leave enough scheduling margin. At 8 MS/s the interval is 400 clocks and the
same detector is repeatably error-free. The current verified hardware rate is
therefore 500 kbit/s; reaching 1 Mbit/s requires further parallelism or a
higher detector clock.

## FPGA build

Vivado 2026.1 generated the image for `xc7z010clg400-1` and reported:

| Check | Result |
|---|---:|
| Worst setup slack | +0.038 ns |
| Worst hold slack | +0.016 ns |
| Bitstream DRC errors | 0 |
| Slice LUTs | 11,833 / 17,600 (67.23%) |
| Slice registers | 17,948 / 35,200 (50.99%) |
| Block RAM tiles | 25.5 / 60 (42.50%) |
| DSP slices | 52 / 80 (65.00%) |

The RAM-loadable FPGA-manager file is
`plutoplus-vivado2026/artifacts/cpm-h-rx-auto-loop/pluto_cpm_h_rx_auto_loop.bit.bin`.
Its SHA-256 is
`73e69c02378a48230829d4cdb1bf72d99fab6c0b4c0eaaf4cfd25b1b75fcabe6`.
Generated bitstreams and checkpoints are ignored by Git; the timing, DRC,
utilization, and CDC reports are retained with the build scripts.

## Repeat test

Load the temporary image with
`Pluto-SDR/load-cpm-h-rx-auto-loop-temporary.sh`, configure both converter
directions for 8 MS/s, then run:

```powershell
python Pluto-SDR/cpm-h/tx_cpm_h_dma.py --uri ip:192.168.2.1 `
  --frequency 915000000 --sample-rate 8000000 --rf-bandwidth 3000000 `
  --tx-gain -30 --samples-per-dibit 32
```

On the Pluto, execute:

```sh
/tmp/cpm-h-rx-control.sh auto
```

The image is loaded only into FPGA RAM. A Pluto power cycle restores the
persisted boot image.
