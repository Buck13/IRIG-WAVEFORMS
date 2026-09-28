# IRIG-WAVEFORMS
irig 106-20 CPM WAVEFORM DEFINITIONS

## ARTM multi-h CPM

The [CPM-H project](CPM-H/README.md) contains explanatory notebooks, Python models, plots, and teaching VHDL:

- [Waveform and spectrum notebook](CPM-H/ARTM_CPM_explained.ipynb): dibits, pulse shaping, frequency, phase, I/Q, VCO interpretation, and spectrum.
- [Python-to-VHDL notebook](CPM-H/ARTM_CPM_hardware_Python_to_VHDL.ipynb): three overlapping pulse paths, fixed-point arithmetic, and clocked RTL simulation.
- [Source guide](CPM-H/SOURCES.md) and [VHDL simulation instructions](CPM-H/hardware/README.md).

The notebooks include saved outputs. Run from the `CPM-H` directory after installing its `requirements.txt`.
These are educational models; FPGA timing closure and RF compliance are not established.
