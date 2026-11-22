# SOQPSK / CPM-H FPGA workflow reuse

The existing CPM-H receiver already supplies the hardware patterns we need:

| CPM-H block | SOQPSK reuse |
|---|---|
| `cpm_rx_observation_adapter` | sample-enable, epoch, symbol-boundary adapter |
| `cpm_complex_correlator` | I/Q matched-filter/template correlation lane |
| `cpm_correlation_bank` | parallel SOQPSK branch-template bank |
| `cpm_phase_acs4` | add-compare-select metric pipeline, expanded for SOQPSK states |
| `cpm_survivor_traceback` | survivor RAM and traceback control |
| `run-sim.ps1` | repeatable compile/elaboration/simulation workflow |

The main difference is the SOQPSK front end: the pulse span is eight bits,
carrier/timing correction must precede branch metrics, and the current exact
reference decoder has 256 pulse-memory states. The implementation plan is to
reuse the CPM-H streaming contracts and traceback machinery while replacing
the six-template correlation bank and four-state ACS with quantized SOQPSK
branch templates and a resource-bounded state schedule.
