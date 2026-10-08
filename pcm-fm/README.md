# PCM-FM offline prototype

Start with [the executed explainer notebook](pcm_fm_explainer.ipynb). It includes
plots, equations, the integer interface contract, measured errors and limitations.

- `pcm_fm.py`: floating-point reference, streaming integer model and validation.
- `make_notebook.py`: executes the explanation cells and embeds their figures.
- `results/`: plots, validation metrics, 4096 HDL sample vectors and exact tables.

Requires Python, NumPy and Matplotlib (`requirements.txt`). From this folder:

```powershell
python pcm_fm.py
python make_notebook.py
```

Opening/rerunning notebook cells interactively additionally requires a Jupyter
frontend and Python kernel. Generating the executed notebook does not.

Defaults: 2.5 MS/s, 312.5 kbit/s, PN15, h=0.7, nominal deviation 109375 Hz,
65-tap Bessel-derived FIR, 32-bit phase accumulator and 12-bit sine-table address.
The selected sixth-order analog target comes from RCC 106-22 Chapter 2 Table 2-3.
See [FILTER-DECISION.md](FILTER-DECISION.md) for selection and measured tolerances.

Run `python pcm_fm.py`, `python validate_filter.py`, then `python make_notebook.py`.
Full-period validation covers 32767 symbols / 262136 samples. Updated numeric
results are in `results/metrics.json`; filter comparisons are in
`results/filter-validation.json`. SHA-256 hashes freeze the coefficient/ROM/vector
files in `results/reference-sha256.json`.

The VHDL core now passes exact XSIM comparison over 268280 samples. See
[HDL architecture](HDL.md) and [simulation result](results/XSIM-RESULT.md).
Pluto integration, resource usage, timing closure and physical PCM-FM transmission remain pending.
The existing BPSK design has not been modified.

## Two-notebook reading order

1. [Notebook 1: waveform explanation](pcm_fm_explainer.ipynb).
2. [Notebook 2: fixed-point model and RTL/HDL mapping](pcm_fm_low_level.ipynb).

Both execute independently. Notebook 2 adds integer sample traces, width bounds,
accepted-sample behavior, proposed HDL interfaces and a VHDL phase-update sketch.
The notebook sketch is explanatory; the implemented VHDL core is in `hdl/pcm_fm_core.vhd`.

## Standalone synthesis result

The routed XC7Z010 core uses 692 LUTs, 737 registers, 4 BRAM tiles and 2 DSPs.
Internal timing passes at the 100 MHz target; boundary hold violations remain
in the isolated build. See [the complete report](results/standalone/RESULT.md).
