"""High-level coherent ARTM CPM sequence detection; ideal synchronization."""
from functools import lru_cache
from itertools import product
import numpy as np

ALPHABET = np.array([-3, -1, 1, 3])

def phase_pulse(u):
    v = np.clip(np.asarray(u, dtype=float), 0, 3)
    return v/6 - np.sin(2*np.pi*v/3)/(4*np.pi)

def modulate(dibits, sps=8):
    """Independent analytic TX; zero prehistory, first symbol uses h=4/16."""
    a = ALPHABET[np.asarray(dibits, dtype=int)]
    impulses = np.zeros(len(a)*sps)
    impulses[::sps] = a*np.resize([4/16, 5/16], len(a))
    dq = np.diff(phase_pulse(np.arange(3*sps+1)/sps))
    phase = np.r_[0., np.cumsum(np.convolve(impulses,dq))]
    return np.exp(2j*np.pi*phase[:len(impulses)])

@lru_cache(maxsize=4096)
def branches(parity, state, sps):
    """state=(completed phase index p, previous symbol b, older symbol c).

    p/32 is phase in turns from fully completed pulses. b,c=0 are startup
    sentinels only; they are not valid data symbols. Even H=4; odd H=5.
    """
    p,b,c = state
    H = 4+parity
    u = np.arange(sps)/sps
    turns = (p/32 + (9-H)*b/16*phase_pulse(u+1)
             + H*c/16*phase_pulse(u+2)
             + H*ALPHABET[:,None]/16*phase_pulse(u))
    templates = np.exp(2j*np.pi*turns)
    next_states = tuple(((p+H*c)%32, int(a), b) for a in ALPHABET)
    return templates, next_states

def viterbi(received, sps=8, known=None):
    """Minimum squared-IQ-distance sequence, with full-block traceback.

    known maps symbol positions to known dibits (e.g. a trailing pilot).
    No payload bits enter the detector. AWGN variance is common to all paths,
    so the common likelihood scale can be omitted from the metric.
    """
    y = np.asarray(received).reshape(-1,sps)
    known = {} if known is None else known
    metrics = {(0,0,0): 0.}
    survivors, counts, phase_metrics = [], [], []
    for n, observation in enumerate(y):
        candidates = [int(known[n])] if n in known else range(4)
        updated, links = {}, {}
        for state, cost in metrics.items():
            templates, destinations = branches(n%2, state, sps)
            distances = np.sum(np.abs(templates-observation[None,:])**2,axis=1)
            for d in candidates:
                destination = destinations[d]
                proposed = cost+float(distances[d])
                if proposed < updated.get(destination,np.inf):
                    updated[destination] = proposed
                    links[destination] = (state,d)
        metrics = updated
        survivors.append(links)
        counts.append(len(metrics))
        row = np.full(32,np.inf)
        for (p,b,c), cost in metrics.items(): row[p] = min(row[p],cost)
        phase_metrics.append(row-min(metrics.values()))
    best_state = min(metrics,key=metrics.get)
    best_cost = metrics[best_state]
    decoded = np.empty(len(y),dtype=int)
    state_path = [best_state]
    for n in range(len(y)-1,-1,-1):
        best_state,decoded[n] = survivors[n][best_state]
        state_path.append(best_state)
    return decoded, {'cost':best_cost, 'states':np.array(counts),
                     'phase_metrics':np.array(phase_metrics),
                     'path':list(reversed(state_path))}

def bit_errors(actual, decoded):
    a=np.asarray(actual); b=np.asarray(decoded)
    return int(np.sum((a>>1)!=(b>>1))+np.sum((a&1)!=(b&1)))

def brute_force(received, payload_length, tail, sps=8):
    """Tiny-block independent exhaustive reference; exponential complexity."""
    candidates = list(product(range(4),repeat=payload_length))
    costs = []
    for candidate in candidates:
        waveform=modulate([*candidate,*tail],sps)
        costs.append(np.sum(np.abs(received-waveform)**2))
    winner=int(np.argmin(costs))
    return np.asarray(candidates[winner]),float(costs[winner])
