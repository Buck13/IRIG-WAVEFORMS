# Low-level CPM-H receiver

`cpm_receiver_hardware.py` is the fixed-point golden model for the first
receiver RTL boundary. It expects dibit-aligned, carrier-corrected IQ. The model
quantizes IQ/templates to signed 12-bit integers, accumulates integer squared
IQ errors, renormalizes path metrics every dibit, stores survivor choices, and
performs traceback through the ARTM multi-h CPM trellis.

`CPM_H_receiver_Python_to_VHDL.ipynb` explains the arithmetic and throughput
limit. Regenerate it with `build_receiver_notebook.py`.

The VHDL now implements the complete manually aligned receive chain:

- `hardware/cpm_branch_metric.vhd`: one streaming squared-IQ branch metric;
- `hardware/tb_cpm_branch_metric.vhd`: checks Python vectors;
- `hardware/branch_metric_vectors.txt`: 384 sample-level golden vectors.

Run the checks from this directory:

```powershell
& ..\..\..\.venv\Scripts\python.exe .\cpm_receiver_hardware.py
.\hardware\run-sim.ps1
```

The Python fixed-point Viterbi recovered the saved Pluto loopback capture with
zero errors over 1024 bits. The RTL now includes template correlation,
two-lane ACS scheduling, survivor RAM, bounded traceback, a manual observation
adapter, clock crossing and processor controls. Automatic carrier/timing/epoch
acquisition remains to be implemented.

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

## Two-lane state scheduler

`viterbi_scheduler.py` exports the four steady-state epoch tables used by
`hardware/cpm_state_scheduler.vhd`. The VHDL scheduler issues two destination
states per clock and completes 256 states in 128 clocks. See
`results/SCHEDULER_RESULT.md` for verification and the synchronous-BRAM metric
memory requirement discovered during synthesis.

## Integrated Viterbi engine

`hardware/cpm_viterbi_engine.vhd` is the single-block state-update engine. It
accepts the 64 correlation results for one dibit and emits the two-lane survivor
write stream used by the future traceback memory. Its functional and 100 MHz
synthesis results are recorded in `results/VITERBI_ENGINE_RESULT.md`.
## Survivor traceback

`hardware/cpm_viterbi_decoder.vhd` combines the state-update engine with a
32-dibit survivor history and traceback controller. After its history fills it
emits recovered dibits. Verification and full wrapper synthesis figures are in
`results/TRACEBACK_RESULT.md`.
## Correlation front end and complete detector

hardware/cpm_correlation_bank.vhd implements the 64-template front end with six complex-MAC lanes and accepts each of the 16 aligned observations in a 12-clock interval. hardware/cpm_h_detector.vhd connects it directly to the Viterbi and traceback blocks. The complete aligned-input detector meets 100 MHz on the XC7Z010 and uses 36.64% LUT, 23.62% registers, 38.33% BRAM, and 50% DSP. See results/CORRELATION_DETECTOR_RESULT.md for the verification, throughput boundary, and remaining synchronization work.

## Pluto RX-only image

`hardware/cpm_rx_observation_adapter.vhd` and
`hardware/pluto_cpm_rx_controlled.vhd` connect the detector to a selected Pluto RX
stream with manual timing-offset and starting-epoch controls. The complete
RX-only image fits the XC7Z010 and passes post-route timing and DRC. See
`results/MANUAL_RX_INTEGRATION_RESULT.md` for resource use, control-register
layout, limitations and artifact location.

## Automatic PN15 loopback image

The `cpm-h-rx-auto-loop` image keeps the normal DMA transmit path and connects
the CPM-H detector to RX2. `hardware/cpm_pn15_quality.vhd` learns 15 decoded
bits and checks the following 64 bits against the PN15 recurrence. The
device-side `auto` command searches 32 sample offsets and four CPM epochs.

The physical TX1 -> 30 dB attenuator -> RX2 test passed five consecutive
automatic acquisitions with 0/64 PN15 errors at 500 kbit/s (8 MS/s and 32
samples/dibit). No input samples were dropped and no detector overflow was
reported. At 1 Mbit/s the current 100 MHz implementation reports dropped
samples, so 500 kbit/s is the verified real-time rate for this build. See
`results/AUTO_RX_LOOPBACK_RESULT.md` for build, resource, and test details.
