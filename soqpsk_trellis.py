"""SOQPSK-TG reduced trellis reference decoder.

The state is the previous two binary symbols.  A one-bit transition either
holds the CPM frequency pulse (bit 0) or emits the alternating +/- branch
for bit 1.  The implementation is max-log and emits an LLR per bit.

This is the clean reference architecture for the RTL; exact IRIG-106 pulse
coefficients can be substituted in `expected_branch` without changing the
decoder interface.
"""
from __future__ import annotations
import numpy as np

NSTATES = 4
AMP = 1.0

def expected_branch(state: int, bit: int) -> float:
    if bit == 0: return 0.0
    return AMP if (state & 1) == 0 else -AMP

def decode(observation, traceback=8):
    y = np.asarray(observation, dtype=float)
    pm = np.full(NSTATES, -np.inf); pm[0] = 0.0
    survivors=[]; llrs=[]; decisions=[]
    for obs in y:
        nxt=np.full(NSTATES, -np.inf); prev=np.zeros(NSTATES,dtype=np.int8)
        best0=-np.inf; best1=-np.inf
        for s in range(NSTATES):
            if not np.isfinite(pm[s]): continue
            for bit in (0,1):
                ns=((s<<1)|bit)&3
                e=expected_branch(s,bit)
                score=pm[s] + 2*obs*e - e*e
                if score > nxt[ns]: nxt[ns]=score; prev[ns]=s
                if bit==0: best0=max(best0,score)
                else: best1=max(best1,score)
        pm=nxt; survivors.append(prev); llrs.append(best0-best1)
        decisions.append(int(best1>best0))
    # Traceback from the best ending state gives the survivor sequence.
    state=int(np.argmax(pm)); out=[]
    for k in range(len(y)-1,-1,-1):
        old=int(survivors[k][state]); out.append(state&1); state=old
    return np.asarray(out[::-1],dtype=np.uint8), np.asarray(llrs)

if __name__ == '__main__':
    tx=np.array([1,0,1,1,0,0,1,0,1,1],dtype=np.uint8)
    # Idealized branch observations with modest noise.
    state=0; obs=[]
    for b in tx:
        obs.append(expected_branch(state,int(b))); state=((state<<1)|int(b))&3
    rx,llr=decode(obs)
    print('tx=', ''.join(map(str,tx.tolist())))
    print('rx=', ''.join(map(str,rx.tolist())))
    print('llr=', np.round(llr,2).tolist())
