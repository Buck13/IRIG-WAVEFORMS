# Low-level CPM-H receiver

`cpm_receiver_hardware.py` is the fixed-point golden model for the first
receiver RTL boundary. It expects dibit-aligned, carrier-corrected IQ. The model
quantizes IQ/templates to signed 12-bit integers, accumulates integer squared
IQ errors, renormalizes path metrics every dibit, stores survivor choices, and
performs traceback through the ARTM multi-h CPM trellis.

`CPM_H_receiver_Python_to_VHDL.ipynb` explains the arithmetic and throughput
limit. Regenerate it with `build_receiver_notebook.py`.

The current VHDL implements and verifies the first reusable unit:

- `hardware/cpm_branch_metric.vhd`: one streaming squared-IQ branch metric;
- `hardware/tb_cpm_branch_metric.vhd`: checks Python vectors;
- `hardware/branch_metric_vectors.txt`: 384 sample-level golden vectors.

Run the checks from this directory:

```powershell
& ..\..\..\.venv\Scripts\python.exe .\cpm_receiver_hardware.py
.\hardware\run-sim.ps1
```

The Python fixed-point Viterbi recovered the saved Pluto loopback capture with
zero errors over 1024 bits. This does not make the present VHDL a complete
real-time detector. Template/correlation parallelism, ACS scheduling, survivor
RAM, bounded traceback, and acquisition/tracking remain to be implemented and
measured.

## Observation-count experiment

`metric_reduction_experiment.py` compares 32, 16, 8 and 4 IQ observations per
dibit against the saved Pluto capture and controlled noisy signals. The first
RTL target is 16 evenly spaced observations per dibit. See
`results/metric-reduction/RESULT.md` for the measured errors and cycle-budget
implications.

## Factorized correlation-bank metric

`correlation_bank_experiment.py` proves the 64-base-waveform correlation
factorization against the Pluto capture, noisy vectors, and the original direct
squared-distance detector. `hardware/cpm_complex_correlator.vhd` is the first
streaming complex-MAC lane. Results are in `results/correlation-bank/`.

## Phase-score and ACS lane

`hardware/cpm_phase_acs4.vhd` evaluates the four legal predecessors of one CPM
destination state and emits its winning metric and two-bit survivor. The
18-bit correlation normalization is verified in the complete Python detector.
Standalone XC7Z010 synthesis results are recorded in
`results/PHASE_ACS_RESULT.md`.
