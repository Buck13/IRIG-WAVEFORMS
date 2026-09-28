# ARTM multi-h CPM exploration

Start with `SOURCES.md`, then open `ARTM_CPM_explained.ipynb` in Jupyter or VS Code.
Select this project's `.venv/Scripts/python.exe` as the notebook kernel and run all cells.
The notebook includes explanations, signal generation, frequency/phase/IQ plots, a Welch spectrum, estimated 99% bandwidth, and controlled parameter comparisons.

To install into a fresh Python environment: `python -m pip install -r requirements.txt`.
To regenerate the notebook source: `python build_notebook.py` (this clears saved cell outputs).
Plots are also saved in `figures/` when the notebook runs.

The notebook is an educational baseband model, not a complete telemetry transmitter or receiver. Source edition and model limitations are documented in `SOURCES.md`.

## Notebook 2: hardware implementation

Open `ARTM_CPM_hardware_Python_to_VHDL.ipynb` for the three-path hardware architecture, pulse-area LUT,
clocked Python model, fixed-point phase accumulator, and VHDL translation. It includes diagrams, branch-by-branch plots,
an illustrative I/Q output ROM, and numerical comparisons with the floating-point model.

`cpm_hardware.py` holds the reusable integer model and exports the coefficient package and test vectors.
`build_hardware_notebook.py` regenerates notebook 2. The VHDL core and testbench are in `hardware/`;
see `hardware/README.md` for the interface contract and simulation commands.

Validation: all notebook cells executed; maximum phase error over 4096 random symbols was 0.000514 degrees
against the floating-point reference (before output sine/cosine quantization). GHDL 6.0.0 compiled the VHDL
and passed all 6000 clock vectors, including stalls and resets. FPGA synthesis and timing closure have not been performed.

Architecture status: the current code uses a shared pulse ROM and signed multipliers. The agreed next revision is
two even/odd banks containing four fully mapped signed pulses each, selected by the three overlapping-symbol paths.
That banked architecture has been discussed but is not implemented in this snapshot.
