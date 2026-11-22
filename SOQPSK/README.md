# SOQPSK-TG receiver

This folder contains the complete SOQPSK development path, kept separate from
the CPM-H and Pluto-SDR projects.

## Workflow

1. Python waveform, synchronization, and trellis references.
2. Quantized pulse and branch-template exporters.
3. VHDL sample adapter, FIR, correlation bank, and trellis blocks.
4. XSIM smoke tests and BER regressions.

The current hardware path is:

```text
ADC samples -> rx_adapter -> FIR -> correlation_bank -> trellis/traceback
```

The correlation bank currently exposes a modular observation interface. The
next integration step is to connect its metric stream to a scheduled
SOQPSK survivor/traceback engine based on the CPM-H implementation.
