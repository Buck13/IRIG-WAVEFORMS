# ARTM multi-h CPM teaching RTL

Run `python cpm_hardware.py` from the repository root to generate the ROM and Python golden vectors.
Parameters are fixed to 32 samples/symbol and a 24-bit phase accumulator. Regenerate the package if these are changed; recheck ranges and tests.

From this directory, with GHDL installed:

```powershell
ghdl -a --std=08 cpm_rom_pkg.vhd cpm_core.vhd tb_cpm_core.vhd
ghdl -e --std=08 tb_cpm_core
ghdl -r --std=08 tb_cpm_core --assert-level=error
```

The testbench checks every clock against Python, including missing input at boundaries, clock-enable gaps, resets, repeated dibits, signed increments, and modular phase wrap.

`dibit_ready` indicates a symbol boundary. Transfer requires ready AND dibit_valid AND sample_ce, with reset low. The first dibit bit is bit 1 (MSB). First accepted symbol uses H=4; subsequent accepted symbols alternate H=5, H=4, etc. Reset clears history and phase.

`out_valid` marks each accepted waveform sample. `phase_word` is the phase at the start of that sample interval; `delta_word` is the signed phase increment across it. The accumulator wraps modulo 2^24. Convert delta to average frequency in Hz with `delta_word * sample_rate / 2^24`. Feed phase to a sine/cosine ROM or CORDIC for I/Q; that block is illustrated in Python, not included in this RTL.

Input starvation and sample_ce=0 freeze waveform time. This is an educational handshake, not a way to pause an RF carrier harmlessly: a streaming DAC needs uninterrupted samples at its configured rate. Buffer input and ensure a dibit every 32 sample advances in continuous operation. Input at other sample positions is not accepted. No end-of-burst or zero-tail flushing interface is included; `00` is data, not an empty symbol.

The arithmetic is expressed as a single-cycle path with three asynchronous ROM reads. Synthesis may choose logic or distributed ROM. A block-RAM/DSP implementation needs explicit latency alignment and pipelining. No target FPGA, timing closure, analog interface, or RF compliance claim is made.
