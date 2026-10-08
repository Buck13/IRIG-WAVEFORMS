"""Offline PCM-FM reference and explicit integer model. No device access."""
from pathlib import Path
import json
import numpy as np

FS = 2_500_000
SPS = 8
RB = FS / SPS
DEVIATION = .35 * RB
AMPLITUDE = 16384
FRAC = 17
PHASE_BITS = 32
LUT_BITS = 12

def pn15(count, seed=0x7fff):
    state = seed or 0x7fff
    bits = []
    for _ in range(count):
        bits.append(state & 1)
        state = (state >> 1) | (((state >> 14 ^ state) & 1) << 14)
    return np.array(bits, dtype=np.int64)

def coefficients():
    # 65-tap causal linear-phase windowed-sinc prototype; .7 Rb is
    # the ideal sinc cutoff, approximately -6 dB, NOT a specified -3 dB BW.
    n = np.arange(65) - 32
    fc = .7 * RB / FS
    taps = 2 * fc * np.sinc(2 * fc * n) * np.hamming(65)
    return taps / taps.sum()

def quantized_coefficients():
    q = np.rint(coefficients() * (1 << FRAC)).astype(np.int64)
    q[32] += (1 << FRAC) - int(q.sum())
    return q

def round_shift(value, shift):
    """Nearest integer, ties away from zero; works for negative products."""
    value = int(value)
    return (1 if value >= 0 else -1) * ((abs(value) + (1 << (shift-1))) >> shift)

def reference(bits):
    nrz = np.repeat(2 * np.asarray(bits) - 1, SPS)
    shaped = np.convolve(nrz, coefficients())[:len(nrz)]
    phase = np.cumsum(shaped * (2*np.pi*DEVIATION/FS))
    return nrz, shaped, phase, AMPLITUDE * np.exp(1j*phase)

class IntegerModulator:
    """One accepted sample per tick. valid=False freezes all state.

    FIR history stores signed +/-1 (2 bits), coefficients signed 18 bits
    with 17 fractional bits. FIR sum signed 21 bits, multiply signed 50
    bits, rounded increment signed 32 bits. Phase unsigned 32-bit wrap.
    Output uses phase AFTER adding this sample's increment. Pipeline
    latency is deliberately unspecified until HDL scheduling is chosen.
    """
    def __init__(self):
        self.coeff = quantized_coefficients()
        self.gain = int(np.rint(DEVIATION/FS * (1 << PHASE_BITS)))
        self.lut = np.rint(AMPLITUDE*np.sin(2*np.pi*np.arange(1 << LUT_BITS)/(1 << LUT_BITS))).astype(np.int64)
        self.reset()
    def reset(self):
        self.history = [0]*65
        self.phase = 0
        self.last = (0, 0, 0, AMPLITUDE, 0)
    def tick(self, symbol, valid=True):
        if not valid:
            return self.last
        assert symbol in (-1, 1)
        self.history = [int(symbol)] + self.history[:-1]
        acc = sum(x*int(c) for x,c in zip(self.history,self.coeff))
        product = acc*self.gain
        assert -(1<<20) <= acc < (1<<20)
        assert -(1<<49) <= product < (1<<49)
        inc = round_shift(product, FRAC)
        self.phase = (self.phase + inc) & 0xffffffff
        address = self.phase >> (PHASE_BITS-LUT_BITS)
        q = int(self.lut[address])
        i = int(self.lut[(address+(1 << (LUT_BITS-2))) % (1 << LUT_BITS)])
        self.last = (acc, inc, self.phase, i, q)
        return self.last

def integer_model(bits):
    model = IntegerModulator()
    return np.array([model.tick(int(x)) for x in np.repeat(2*np.asarray(bits)-1,SPS)], dtype=np.int64)

def validate(out):
    out = Path(out); out.mkdir(exist_ok=True)
    bits = pn15(32767)
    assert np.array_equal(pn15(32782)[32767:], pn15(15))
    assert bits.sum() == 16384
    for pattern in [np.ones(128,dtype=int), np.zeros(128,dtype=int), np.arange(128)%2]:
        n,s,p,z = reference(pattern)
        rows = integer_model(pattern)
        expected = np.convolve(n, quantized_coefficients())[:len(n)]
        assert np.array_equal(rows[:,0],expected)
        if np.all(pattern == pattern[0]):
            assert np.all(rows[65:,1] == (1 if pattern[0] else -1)*IntegerModulator().gain)
    nrz, shaped, phase, ideal = reference(bits)
    rows = integer_model(bits)
    # Independent vector convolution verifies the streaming FIR history/order.
    assert np.array_equal(rows[:,0], np.convolve(nrz,quantized_coefficients())[:len(nrz)])
    expected_phase = np.cumsum(rows[:,1],dtype=np.int64) & 0xffffffff
    assert np.array_equal(rows[:,2], expected_phase)
    model = IntegerModulator()
    rng = np.random.default_rng(15)
    for symbol, expected in zip(nrz[:4096],rows[:4096]):
        for _ in range(int(rng.integers(0,4))):
            before = (model.phase,tuple(model.history),model.last)
            model.tick(int(symbol),False)
            assert before == (model.phase,tuple(model.history),model.last)
        assert np.array_equal(model.tick(int(symbol)),expected)
    model.reset()
    assert model.tick(1) == IntegerModulator().tick(1)
    actual = rows[:,3]+1j*rows[:,4]
    phase_error = np.angle(actual*np.conj(ideal))
    metrics = dict(symbols=len(bits),samples=len(nrz),sample_rate_hz=FS,bit_rate=RB,
        nominal_deviation_hz=DEVIATION,modulation_index=2*DEVIATION/RB,
        fir_delay_samples=32,coefficient_sum=int(quantized_coefficients().sum()),
        max_phase_error_rad=float(np.max(abs(phase_error))),
        relative_iq_rms_error=float(np.sqrt(np.mean(abs(actual-ideal)**2))/AMPLITUDE),
        max_envelope_error_counts=float(np.max(abs(abs(actual)-AMPLITUDE))),
        shaped_peak=float(np.max(abs(shaped))),
        increment_gain=IntegerModulator().gain,
        checks='PN period/balance; constant +/-; alternating; FIR convolution; phase wrap; random stalls; reset')
    assert metrics['max_phase_error_rad'] < .003
    assert metrics['relative_iq_rms_error'] < .003
    assert metrics['max_envelope_error_counts'] < 1
    np.savetxt(out/'hdl_vectors.csv', np.column_stack((nrz[:4096],rows[:4096])),fmt='%d',delimiter=',',header='nrz,fir_q17,increment,phase_u32,i_s16,q_s16',comments='')
    np.savetxt(out/'coefficients_q17.txt',quantized_coefficients(),fmt='%d')
    np.savetxt(out/'sine_lut_s16.txt',IntegerModulator().lut,fmt='%d')
    (out/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    return metrics, (nrz,shaped,phase,ideal,rows)

if __name__ == '__main__':
    metrics,_ = validate(Path(__file__).parent/'results')
    print(json.dumps(metrics,indent=2))
