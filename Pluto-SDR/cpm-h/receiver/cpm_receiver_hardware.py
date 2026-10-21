"""Fixed-point reference for the first CPM-H receiver RTL boundary.

Input IQ must already be dibit-aligned and corrected for constant carrier
phase/gain. The model uses integer template samples, integer Euclidean branch
metrics, metric renormalization, and exact CPM trellis transitions.
"""
from functools import lru_cache
from pathlib import Path
import numpy as np

SPS = 32
IQ_BITS = 12
IQ_PEAK = (1 << (IQ_BITS - 1)) - 1
ALPHABET = np.array([-3, -1, 1, 3], dtype=np.int8)


def phase_pulse(u):
    v = np.clip(np.asarray(u, dtype=float), 0, 3)
    return v / 6 - np.sin(2*np.pi*v/3) / (4*np.pi)


def quantize_iq(z, peak=IQ_PEAK):
    """Round and saturate complex unit-amplitude IQ to signed integers."""
    z = np.asarray(z)
    lo, hi = -peak-1, peak
    i = np.clip(np.rint(z.real*peak), lo, hi).astype(np.int16)
    q = np.clip(np.rint(z.imag*peak), lo, hi).astype(np.int16)
    return i, q


@lru_cache(maxsize=8192)
def branch_bank(parity, state, sps=SPS):
    """Four quantized candidate waveforms and destination states."""
    p, b, c = state
    H = 4 + int(parity)
    u = np.arange(sps) / sps
    turns = (p/32 + (9-H)*b/16*phase_pulse(u+1)
             + H*c/16*phase_pulse(u+2)
             + H*ALPHABET[:, None]/16*phase_pulse(u))
    wave = np.exp(2j*np.pi*turns)
    ti, tq = quantize_iq(wave)
    destinations = tuple(((p+H*c) % 32, int(a), b) for a in ALPHABET)
    return ti, tq, destinations


def trellis_state(dibits, count):
    """State immediately before absolute symbol count."""
    p = b = c = 0
    for n, dibit in enumerate(np.asarray(dibits)[:count]):
        H = 4 + (n & 1)
        p, b, c = (p + H*c) % 32, int(ALPHABET[int(dibit)]), b
    return p, b, c


def fixed_viterbi(iq_i, iq_q, initial_state=(0, 0, 0),
                  absolute_symbol=0, sps=SPS):
    """Integer full-state Viterbi reference with per-symbol renormalization."""
    ri = np.asarray(iq_i, dtype=np.int32).reshape(-1, sps)
    rq = np.asarray(iq_q, dtype=np.int32).reshape(-1, sps)
    metrics = {tuple(initial_state): 0}
    survivors = []
    renormalization = []
    active_counts = []
    for n, (oi, oq) in enumerate(zip(ri, rq)):
        updated, links = {}, {}
        for state, old_metric in metrics.items():
            ti, tq, destinations = branch_bank((absolute_symbol+n) & 1,
                                                state, sps)
            di = ti.astype(np.int32) - oi[None, :]
            dq = tq.astype(np.int32) - oq[None, :]
            branch_metrics = np.sum(di.astype(np.int64)**2
                                    + dq.astype(np.int64)**2, axis=1)
            for dibit, destination in enumerate(destinations):
                candidate = old_metric + int(branch_metrics[dibit])
                if candidate < updated.get(destination, 1 << 63):
                    updated[destination] = candidate
                    links[destination] = (state, dibit)
        floor = min(updated.values())
        metrics = {state: metric-floor for state, metric in updated.items()}
        survivors.append(links)
        renormalization.append(floor)
        active_counts.append(len(metrics))
    state = min(metrics, key=metrics.get)
    decoded = np.empty(len(ri), dtype=np.uint8)
    states = [state]
    for n in range(len(ri)-1, -1, -1):
        state, decoded[n] = survivors[n][state]
        states.append(state)
    return decoded, {
        "final_metric": int(min(metrics.values())),
        "renormalization": np.asarray(renormalization, dtype=np.int64),
        "active_states": np.asarray(active_counts),
        "state_path": list(reversed(states)),
    }


def dibit_bit_errors(actual, decoded):
    a = np.asarray(actual, dtype=np.uint8)
    b = np.asarray(decoded, dtype=np.uint8)
    return int(np.count_nonzero((a >> 1) != (b >> 1))
               + np.count_nonzero((a & 1) != (b & 1)))


def export_branch_vectors(directory, seed=106, symbols=12):
    """Export clock vectors for the streaming VHDL branch-metric unit."""
    root = Path(directory)
    root.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)
    lines = []
    for symbol in range(symbols):
        state = (int(rng.integers(32)), int(rng.choice(ALPHABET)),
                 int(rng.choice(ALPHABET)))
        dibit = int(rng.integers(4))
        ti, tq, _ = branch_bank(symbol & 1, state)
        oi = np.clip(ti[dibit].astype(int) + rng.integers(-8, 9, SPS),
                     -2048, 2047)
        oq = np.clip(tq[dibit].astype(int) + rng.integers(-8, 9, SPS),
                     -2048, 2047)
        expected = int(np.sum((oi-ti[dibit])**2 + (oq-tq[dibit])**2))
        for m in range(SPS):
            lines.append(f"{int(m==0)} {int(m==SPS-1)} {int(oi[m])} "
                         f"{int(oq[m])} {int(ti[dibit,m])} "
                         f"{int(tq[dibit,m])} {expected if m==SPS-1 else 0}")
    (root / "branch_metric_vectors.txt").write_text("\n".join(lines)+"\n")
    return root / "branch_metric_vectors.txt"


if __name__ == "__main__":
    rng = np.random.default_rng(106)
    dibits = rng.integers(0, 4, 128, dtype=np.uint8)
    # Generate the test waveform from the candidate bank itself, while walking
    # the state. This isolates fixed-point detector and transition arithmetic.
    state = (0, 0, 0); chunks = []
    for n, d in enumerate(dibits):
        ti, tq, destinations = branch_bank(n & 1, state)
        chunks.append(ti[d].astype(float)/IQ_PEAK + 1j*tq[d]/IQ_PEAK)
        state = destinations[d]
    z = np.concatenate(chunks)
    i, q = quantize_iq(z)
    decoded, info = fixed_viterbi(i, q)
    errors = dibit_bit_errors(dibits, decoded)
    assert errors == 0
    print(f"PASS: {2*len(dibits)} bits, {errors} errors; "
          f"steady active states {info['active_states'][-1]}")
    print(f"Exported {export_branch_vectors(Path(__file__).parent/'hardware')}")
