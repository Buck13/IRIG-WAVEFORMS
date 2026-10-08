"""Build an executed notebook using plain Python; no Jupyter needed to generate it."""
from pathlib import Path
import base64, contextlib, io, json, os
import matplotlib
matplotlib.use('Agg')
ROOT=Path(__file__).resolve().parent
os.chdir(ROOT)
cells=[]
def md(s): cells.append(dict(cell_type='markdown',metadata={},source=s.splitlines(True)))
def code(s): cells.append(dict(cell_type='code',metadata={},source=s.splitlines(True),execution_count=None,outputs=[]))
md('''# PCM-FM: from PN15 bits to FPGA arithmetic

Steps 1 and 2 only: an offline explanation and executable integer contract. No radio access, HDL implementation, or Vivado build occurs here.

**Signal path:** PN15 → NRZ levels → sample hold → shaping FIR → frequency deviation → phase accumulator → sine/cosine → signed I/Q.

BPSK changed the sign of I directly. Here a bit changes the *rate of phase rotation*. The accumulated phase remains continuous even when the bit changes. The Pluto RF LO later translates these complex baseband samples to RF.

We reuse 2.5 MS/s and 8 samples/bit: 312.5 kbit/s. Nominal deviation is ±109.375 kHz, giving h = 2 Δf / Rb = 0.7. PCM framing is not implemented: PN15 provides the binary test stimulus.

[RCC 106-17, Appendix A.11](https://www.trmc.osd.mil/wiki/download/attachments/113019664/106-17_Telemetry_Standards.pdf?api=v2&modificationDate=1623181155137&version=1) discusses NRZ filtering and these nominal deviation parameters. This is a prototype, not a compliance-certified waveform.''')
code('''import numpy as np
import matplotlib.pyplot as plt
from pcm_fm import *
metrics, traces = validate('results')
nrz, shaped, phase, ideal, rows = traces
print(json.dumps(metrics, indent=2))''')
md('''## 1. Bits become a smooth frequency command

Bit 0 maps to −1; bit 1 maps to +1. Each level is held for eight accepted samples. A causal 65-tap Hamming-windowed sinc FIR smooths transitions, with 32 samples (four bits) of group delay. Startup history is zero.

The chosen ideal sinc cutoff is 0.7 Rb = 218.75 kHz, approximately the −6 dB point of this FIR. It is **not** a specified −3 dB telemetry filter bandwidth. Its overshoot is preserved rather than clipped; nominal deviation refers to steady constant bits. Filter compliance and spectral-mask selection remain future work.''')
code('''fig, ax = plt.subplots(3,1,figsize=(11,8),constrained_layout=True)
t = np.arange(512)/SPS
ax[0].step(t,nrz[:512],where='post',label='held NRZ'); ax[0].plot(t,shaped[:512],label='causal FIR'); ax[0].legend()
ax[0].set_ylabel('signed command')
ax[1].plot(t,shaped[:512]*DEVIATION/1000); ax[1].axhline(DEVIATION/1000,color='gray',ls='--'); ax[1].axhline(-DEVIATION/1000,color='gray',ls='--'); ax[1].set_ylabel('deviation (kHz)')
ax[2].plot(t,phase[:512]); ax[2].set_ylabel('unwrapped phase (rad)'); ax[2].set_xlabel('bit intervals')
fig.savefig('results/stages.png',dpi=150)
plt.show()''')
md('''## 2. Frequency integrates into phase, then I/Q

For sample n, f[n] = Δf × shaped[n]. The phase update is φ[n] = φ[n−1] + 2π f[n]/Fs, starting with φ[−1] = 0. Output uses the updated phase: I[n] = A cos(φ[n]), Q[n] = A sin(φ[n]), with A = 16384.

The ideal envelope is constant. Wrapping numerical phase modulo 2π does not create a waveform discontinuity. The positive sign convention makes a positive command rotate counterclockwise in the I/Q plane.''')
code('''fig, ax = plt.subplots(1,3,figsize=(14,4),constrained_layout=True)
ax[0].plot(np.arange(192)/SPS,ideal.real[:192],label='I'); ax[0].plot(np.arange(192)/SPS,ideal.imag[:192],label='Q'); ax[0].legend(); ax[0].set_xlabel('bit intervals')
ax[1].plot(ideal.real[:1024],ideal.imag[:1024],'.',ms=2); ax[1].axis('equal'); ax[1].set_xlabel('I'); ax[1].set_ylabel('Q')
z=ideal[1024:1024+65536]; w=np.hanning(len(z)); p=abs(np.fft.fftshift(np.fft.fft(z*w)))**2
f=np.fft.fftshift(np.fft.fftfreq(len(z),1/FS))
ax[2].plot(f/1000,10*np.log10(np.maximum(p/p.max(),1e-12))); ax[2].set_xlim(-800,800); ax[2].set_ylim(-100,0); ax[2].set_xlabel('baseband frequency (kHz)'); ax[2].set_ylabel('relative periodogram (dB)')
fig.savefig('results/iq-spectrum.png',dpi=150)
plt.show()''')
md('''## 3. Replace real numbers with an explicit integer contract

| Stage | Representation / rule |
|---|---|
| NRZ history | signed 2-bit −1/+1; zero only in reset history |
| FIR coefficients | signed 18-bit integers, 17 fractional bits; symmetric; sum exactly 131072 |
| FIR accumulator | signed 21-bit; no intermediate rounding |
| Deviation gain | 187904819, unsigned 28-bit phase units per sample at unit command |
| Multiply | signed 50-bit, then shift right 17 with nearest rounding, ties away from zero |
| Phase increment | signed 32-bit |
| Phase accumulator | unsigned 32-bit, wraps modulo 2³² |
| Sine address | upper 12 phase bits; lower bits discarded |
| I/Q | sine ROM with 4096 signed 16-bit entries, amplitude 16384; cosine uses quarter-cycle offset |

Coefficients and ROM are rounded with NumPy nearest-even during table generation. The runtime multiply has a separately specified ties-away rule. A full sine ROM is 65536 bits; eventual FPGA mapping is not yet measured.

`valid=False` freezes FIR history, phase, and output. Reset clears FIR and phase. Each valid call represents one accepted sample; an HDL pipeline may add latency, which must be tracked with valid signals. This model does not specify clock-cycle scheduling, backpressure wiring, or an achievable FPGA clock rate.''')
code('''actual = rows[:,3] + 1j*rows[:,4]
fig, ax = plt.subplots(2,1,figsize=(11,6),constrained_layout=True)
ax[0].plot(np.arange(2048)/SPS,np.angle(actual[:2048]*np.conj(ideal[:2048]))*1000); ax[0].set_ylabel('phase error (mrad)')
ax[1].plot(np.arange(2048)/SPS,abs(actual[:2048])-AMPLITUDE); ax[1].set_ylabel('envelope error (counts)'); ax[1].set_xlabel('bit intervals')
fig.savefig('results/integer-error.png',dpi=150)
plt.show()
print('RMS I/Q error: %.5f %%' % (100*metrics['relative_iq_rms_error']))''')
md('''## 4. Evidence and handoff to HDL

The executed checks cover a full 32767-bit PN15 period, sequence balance and repetition, constant positive/negative levels, alternating bits, independent convolution versus streaming FIR, phase wrap, reset and deterministic random stalls. Comparison uses identical startup state with no phase fitting or time alignment.

`results/hdl_vectors.csv` contains 4096 accepted samples, with NRZ input, FIR sum, increment, phase and I/Q expected outputs. `coefficients_q17.txt` and `sine_lut_s16.txt` are the exact integer tables. `metrics.json` records measured errors. Run `python pcm_fm.py` to regenerate checks and vectors; run `python make_notebook.py` to regenerate this executed notebook and plots.

**Next, not implemented here:** agree the shaping response; schedule FIR/phase/ROM VHDL; compare HDL samples against these vectors including stalls and latency; integrate with the proven Pluto TX adapter; then use Vivado timing/resource reports and a new attenuated cable test. The previous BPSK image is untouched.''')

# Split the existing narrative into independently executable notebooks.
all_cells = cells[:]
low_cells = [dict(cell_type='markdown', metadata={}, source=[
    '# Notebook 2: PCM-FM fixed-point model and RTL/HDL mapping\n\n'
    'Companion to [Notebook 1](pcm_fm_explainer.ipynb). This notebook starts from '
    'the verified waveform and follows the integer datapath toward hardware. '
    'It runs independently. The RTL below is an architectural sketch, not a synthesized core.\n'
]), all_cells[1]] + all_cells[6:]
cells = low_cells
md("""## 5. Work through one sample with exact integers

The FIR consumes the newest sample at coefficient zero. Because the input is
only −1, 0 or +1, its tap products can be coefficient negation, zero or addition;
a general multiplier per tap is unnecessary. The frequency scaling multiply is
separate. The FIR signed bound is the sum of the absolute quantized coefficients,
not merely their DC sum. Preserve headroom for transition overshoot.
""")
code("""c = quantized_coefficients()
bound = int(np.abs(c).sum())
required_bits = bound.bit_length() + 1
print('FIR worst-case magnitude:', bound, '; signed bits required:', required_bits)
assert bound < (1 << 20)
m = IntegerModulator()
print('sample   NRZ   FIR-Q17    increment    phase-U32      I      Q')
for n, x in enumerate(nrz[:12]):
    a, d, p, i, q = m.tick(int(x))
    print(f'{n:6d} {x:5d} {a:9d} {d:12d} {p:12d} {i:6d} {q:6d}')
assert round_shift(1,1) == 1 and round_shift(-1,1) == -1
assert round_shift(3,1) == 2 and round_shift(-3,1) == -2
""")
md("""## 6. Proposed HDL blocks and interfaces

```text
PN15 + samples-per-bit counter
        | signed NRZ, sample enable
        v
65-sample history -> signed coefficient add/subtract -> FIR sum
        -> deviation scaling + signed rounding
        -> modulo-2^32 phase register
        -> upper 12 bits -> sine ROM / quarter-cycle cosine
        -> signed 16-bit I/Q + output valid
        -> Pluto TX adapter (integration still pending)
```

| Proposed block | Inputs | Outputs / retained state |
|---|---|---|
| PN15 / bit hold | reset, accepted sample | NRZ; LFSR advances after 8 samples |
| shaping FIR | NRZ, sample enable | signed 21-bit sum; 65 history values |
| deviation scale | sum, valid | signed phase increment; explicit rounding |
| phase accumulator | increment, valid | unsigned wrapped phase |
| phase-to-I/Q | phase, valid | ROM-based signed 16-bit I and Q |

Proposed core ports are `clk`, `reset`, `sample_ce`, `nrz_in`,
`i_out`, `q_out`, and `out_valid`. The source counter advances only when an
input is accepted. A pipelined implementation must propagate each accepted
sample's validity; it must still drain pending outputs when no new input arrives.
The Python freeze rule describes an atomic accepted-sample model, not a rule to
freeze every stage of a future pipeline.

The exact FIR scheduling and pipeline latency remain to be chosen. A serial
adder can save logic if there are enough clocks between samples. A pipelined
adder tree can support greater throughput. Neither resource use nor timing is
established by this notebook.

### VHDL-style phase update sketch

```vhdl
-- Schematic only: inc_valid corresponds to a completed scaling operation.
if rising_edge(clk) then
  if reset = '1' then
    phase <= (others => '0');
    phase_valid <= '0';
  else
    phase_valid <= inc_valid;
    if inc_valid = '1' then
      next_phase := phase + unsigned(increment);
      phase <= next_phase;
      -- ROM address must use next_phase to match the Python convention.
      rom_addr <= next_phase(31 downto 20);
    end if;
  end if;
end if;
```

A synchronous ROM adds a cycle: delay valid to match. Converting the signed
32-bit increment to unsigned preserves its two's-complement bit pattern;
32-bit addition discards carry, giving the intended modulo wrap. Rounding of
negative scaling products must match `round_shift`, not a bare arithmetic shift.
""")
code("""# Observe accepted samples and idle clocks without changing sample order.
m = IntegerModulator()
expected = integer_model(pn15(16))
accepted = 0
print('clock  accept  sample-index  phase-state')
for clock in range(24):
    enable = clock % 3 != 1
    x = int(nrz[accepted])
    row = m.tick(x, enable)
    if enable:
        assert np.array_equal(row, expected[accepted])
    print(f'{clock:5d} {int(enable):7d} {accepted:13d} {m.phase:12d}')
    accepted += int(enable)
print('Accepted-sample ordering verified. HDL output latency remains unspecified.')
""")
md("""## 7. Testbench handoff

1. Load `results/hdl_vectors.csv`; present each NRZ value on an accepted input.
2. Queue its expected I/Q. Compare exactly when the matching `out_valid` arrives,
   rather than assuming that input and output occur on the same clock.
3. Check internal FIR, increment and phase against the corresponding columns.
4. Insert idle input cycles, reset between runs, and explicitly flush the pipeline.
5. Repeat with constant and alternating inputs and a full PN15 period.

The supplied CSV contains 4096 samples (512 bits), not the full-period test.
The Python validation executes the full period. Quantized tables are exact
inputs to the future HDL; HDL equivalence, XSIM and Vivado work are not yet done.
""")
low_cells = cells
high_cells = all_cells[:6]
high_cells[0]['source'][0] = '# Notebook 1: PCM-FM waveform explanation\n'
high_cells.append(dict(cell_type='markdown', metadata={}, source=[
    '## Continue with Notebook 2\n\n'
    '[Fixed-point model and RTL/HDL mapping](pcm_fm_low_level.ipynb) contains '
    'integer widths, rounding, error plots, sample traces, enable behavior and '
    'the proposed hardware block interfaces.\n'
]))
# Notebook 1 calculates only the floating-point waveform.
high_cells[1] = dict(cell_type='code',metadata={},execution_count=None,outputs=[],source=[
    "import numpy as np\nimport matplotlib.pyplot as plt\nfrom pcm_fm import *\n"
    "nrz, shaped, phase, ideal = reference(pn15(32767))\n"
    "print(f'Fs={FS} Hz; Rb={RB} bit/s; deviation={DEVIATION} Hz')\n"
])
def execute_notebook(cells, filename):
    namespace={}
    for cell in cells:
        if cell["cell_type"] == "code": cell["outputs"] = []
    for count,cell in enumerate([c for c in cells if c['cell_type']=='code'],1):
        stream=io.StringIO()
        def show():
            import matplotlib.pyplot as plt
            for number in plt.get_fignums():
                b=io.BytesIO(); plt.figure(number).savefig(b,format='png',dpi=110)
                cell['outputs'].append(dict(output_type='display_data',metadata={},data={'image/png':base64.b64encode(b.getvalue()).decode(),'text/plain':['PCM-FM model figure']}))
            plt.close('all')
        import matplotlib.pyplot as plt
        plt.show=show
        with contextlib.redirect_stdout(stream): exec(''.join(cell['source']),namespace)
        if stream.getvalue(): cell['outputs'].append(dict(output_type='stream',name='stdout',text=stream.getvalue().splitlines(True)))
        cell['execution_count']=count
    notebook=dict(cells=cells,metadata=dict(kernelspec=dict(display_name='Python 3',language='python',name='python3'),language_info=dict(name='python',version='3')),nbformat=4,nbformat_minor=4)
    (ROOT/filename).write_text(json.dumps(notebook,indent=1)+"\n",encoding="utf8")

execute_notebook(high_cells, "pcm_fm_explainer.ipynb")
execute_notebook(low_cells, "pcm_fm_low_level.ipynb")
print("Both notebooks executed successfully.")
