# PCM-FM Pluto adapter

`pluto_pcm_fm_adapter.vhd` adds PN15 (LSB output, all-ones default seed),
eight accepted samples per bit, and a 32-word prefetch FIFO to the verified core.
The bit rate is the delivered sample rate divided by eight. For the reference
2.5 MS/s configuration this is 312.5 kbit/s; other sample rates scale frequency
and bit rate together because the phase increment and h are fixed.

The reservation counter includes both samples in flight and samples in the FIFO.
It prevents overflow without stopping the core pipeline. A 16-sample startup
prefill covers the pipeline latency; once armed, the adapter supports requests
on every clock as well as arbitrarily long request gaps. FIFO reads capture
I/Q after the requesting rising edge, matching the original util_upack path.
The DMA bypass remains combinational.

Startup requests return zero until primed. This is a finite startup interval,
not a steady-state dropped-sample policy. The first valid output is the first
reference sample. The board path has no sample-valid input, so RX analysis must
exclude this startup. No extra zero samples should occur after priming.
A sticky underflow output is provided for simulation/debug but is not connected
to a software status register in this initial integration.

Reset, restart, deselection or loss of paired channel enable clears PN state,
FIR/phase, pending results and FIFO. The top-level synchronizes the ARM selector
through two ASYNC_REG flip-flops and requires both I and Q enabled. GPIO address
0x41210000 bit 0 remains: 0 = DMA, 1 = PCM-FM in this image. This differs from
the BPSK image's meaning of bit 1; software must identify which image is loaded.

`run-adapter-sim.ps1` checks exact outputs, continuous/gapped requests, FIFO
prefill and return to DMA. The top-level is checked with paired-enable changes.
The full Pluto project is isolated under `plutoplus-vivado2026/build/pcm-fm`;
the prior BPSK project and artifacts are retained.
