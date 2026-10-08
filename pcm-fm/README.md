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
65-tap prototype FIR, 32-bit phase accumulator and 12-bit sine-table address.
The FIR sinc cutoff at 0.7 Rb is approximately a -6 dB point, not a specified
telemetry -3 dB bandwidth. Transient overshoot reaches about 1.265 times nominal
command. No spectral-mask compliance is claimed.

Full-period validation: 32767 symbols / 262136 samples; RMS complex sample error
0.089014% versus the floating reference; maximum phase error 0.001635 rad;
maximum envelope error 0.681 count. Also checks constant and alternating inputs,
streaming FIR versus convolution, phase wrap, reset and sample-enable stalls.

These results verify the software arithmetic model only. HDL, pipeline scheduling,
Pluto integration, resource usage and physical PCM-FM transmission remain pending.
The existing BPSK design has not been modified.
