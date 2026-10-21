"""Build the low-level CPM-H receiver Python-to-VHDL notebook."""
from pathlib import Path
import nbformat as nbf

ROOT = Path(__file__).resolve().parent
nb = nbf.v4.new_notebook()
nb["metadata"]["kernelspec"] = {"display_name":"Python 3", "language":"python", "name":"python3"}
nb["cells"] = [
nbf.v4.new_markdown_cell("""# CPM-H receiver: fixed-point Python to VHDL

This notebook is the low-level receiver companion to the transmitter hardware
notebook. Its input boundary is **dibit-aligned, carrier-corrected complex IQ**.
It implements integer template samples, squared-IQ branch metrics, integer path
metrics, per-dibit renormalization, survivor decisions, and traceback.

Acquisition is deliberately outside this first RTL boundary. The preceding
receiver must estimate sample timing, frequency, carrier phase, H=4/H=5 parity,
and a frame/start condition from a preamble or synchronization word."""),
nbf.v4.new_code_cell("""from pathlib import Path
import numpy as np
from cpm_receiver_hardware import *
ROOT=Path.cwd()
print(f'{SPS} samples/dibit, signed {IQ_BITS}-bit IQ, peak {IQ_PEAK}')"""),
nbf.v4.new_markdown_cell("""## Fixed-point interface

The corrected unit-amplitude IQ is quantized to signed 12-bit values. For every
candidate trellis branch, the hardware accumulates

`(rx_i-template_i)^2 + (rx_q-template_q)^2`

over 32 samples. Path metrics are renormalized by subtracting the smallest
metric after every dibit. This preserves decisions and prevents unlimited
growth. The Python model uses wide integers so we can measure the widths needed
before narrowing the RTL."""),
nbf.v4.new_code_cell("""rng=np.random.default_rng(106)
dibits=rng.integers(0,4,128,dtype=np.uint8)
state=(0,0,0); waveform=[]
for n,d in enumerate(dibits):
    ti,tq,dest=branch_bank(n&1,state)
    waveform.append(ti[d]/IQ_PEAK + 1j*tq[d]/IQ_PEAK)
    state=dest[d]
z=np.concatenate(waveform)
i,q=quantize_iq(z)
decoded,info=fixed_viterbi(i,q)
errors=dibit_bit_errors(dibits,decoded)
print(f'PASS: {2*len(dibits)} bits, {errors} errors')
print('active states by startup interval:',info['active_states'][:8])
assert errors==0 and info['active_states'][-1]==256"""),
nbf.v4.new_markdown_cell("""## Real Pluto result

The same fixed-point model was run on the saved 1 Mbit/s TX1-to-RX2 capture.
After the existing PN15 synchronizer supplied alignment, phase, gain, parity,
and initial state, it recovered **1024 bits with zero errors**. This proves that
12-bit template/IQ quantization and integer metrics preserve the decisions for
the captured signal. It remains a short functional test, not a BER curve."""),
nbf.v4.new_code_cell("""hardware_result={
 'sample_rate':16_000_000, 'bit_rate':1_000_000,
 'decoded_bits':1024, 'bit_errors':0, 'ber':0.0,
 'steady_active_states':256, 'max_symbol_metric_floor':805006}
hardware_result"""),
nbf.v4.new_markdown_cell("""## Cycle budget

At 1 Mbit/s there are 500,000 dibits/s. The steady trellis has 256 active
states and four outgoing branches per state: 1024 branch metrics per dibit.
At 100 MHz there are only 200 clocks per dibit. A literal single-lane Viterbi
therefore cannot keep up. At least six branch lanes are needed even if each
lane produces one complete branch metric per clock; the current 32-sample
metric requires a different correlation/template architecture or much more
parallelism. This notebook establishes arithmetic correctness, not final
throughput closure."""),
nbf.v4.new_code_cell("""dibits_per_second=500_000
branches_per_dibit=256*4
cycles_per_dibit=100_000_000/dibits_per_second
print('branches/s:',f'{branches_per_dibit*dibits_per_second:,}')
print('100 MHz clocks/dibit:',cycles_per_dibit)
print('minimum one-branch-per-clock lanes:',int(np.ceil(branches_per_dibit/cycles_per_dibit)))"""),
nbf.v4.new_markdown_cell("""## First VHDL unit

`hardware/cpm_branch_metric.vhd` is a synthesizable streaming squared-IQ metric
accumulator for one candidate. Python exports sample-by-sample vectors covering
positive and negative IQ and multiple candidate waveforms. Its VHDL testbench
checks all 384 samples. This unit is intentionally separate from the future
template generator, parallel scheduler, add-compare-select array, survivor RAM,
and traceback controller."""),
nbf.v4.new_code_cell("""path=export_branch_vectors(ROOT/'hardware')
print('Exported:',path)
print('Run hardware/run-sim.ps1 for the VHDL clock-vector test.')"""),
nbf.v4.new_markdown_cell("""## Next design experiment

The next step is to replace direct 32-sample comparison of every branch with a
smaller correlation representation and measure the BER penalty in Python. Only
after selecting that metric architecture should we build the parallel ACS and
survivor-memory RTL. The fixed-point model here remains the golden reference.""")]

nbf.write(nb, ROOT / "CPM_H_receiver_Python_to_VHDL.ipynb")
print("Built CPM_H_receiver_Python_to_VHDL.ipynb")
