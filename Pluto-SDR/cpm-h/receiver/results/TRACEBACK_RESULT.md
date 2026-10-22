# Survivor memory, traceback, and combined Viterbi decoder

`cpm_survivor_traceback.vhd` stores 32 dibits of two-bit survivor choices for
all 256 states. Two 4096 x 2 simple-dual-port memories accept the engine's even
and odd destination lanes concurrently while synchronous reads trace the best
path backward. Traceback runs concurrently with the following Viterbi update
and emits one delayed decoded dibit per completed input dibit after the history
fills.

`cpm_viterbi_decoder.vhd` wraps this block around `cpm_viterbi_engine.vhd`.
Its external interface is now limited to the 64 complex correlations for each
received dibit, `start`, the four-phase epoch, status, and decoded dibits.

## Verification

A deterministic 40-symbol test writes independently generated survivor choices
and best-state metrics. Python performs the same epoch-aware backward walk.
GHDL verifies all nine outputs produced after the 32-dibit startup delay,
including ring-buffer wraparound. The complete receiver regression also passes.

Vivado confirms that both survivor histories map to one RAMB18E1 each rather
than registers. Synthesis of the combined engine and traceback wrapper for
`xc7z010clg400-1` reports:

- 2,734 LUTs (15.53%);
- 1,824 registers (5.18%);
- 23 of 60 block-RAM tiles (38.33%);
- 16 of 80 DSP48E1 blocks (20%);
- setup WNS +1.774 ns and hold WHS +0.073 ns at 100 MHz;
- zero failing setup or hold endpoints.

This is the complete Viterbi/traceback section, but it is not yet the complete
Pluto receiver. It still expects 64 correlations per aligned received dibit.
The next receiver block must generate those correlations from the Pluto IQ
sample stream and CPM-H reference waveforms. Carrier/timing acquisition and the
Pluto receive-stream adapter remain outside this wrapper.