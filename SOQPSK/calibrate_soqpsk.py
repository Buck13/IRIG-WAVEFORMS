"""Derive branch templates and fixed-point coefficients from the exact pulse."""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
from soqpsk_chain import tx
from soqpsk_frontend import tg_pulse

def branch_templates(sps=8, contexts=512, seed=106):
    rng=np.random.default_rng(seed); sums=np.zeros((4,2)); counts=np.zeros((4,2))
    # Calibrate the reduced trellis against exact-pulse waveforms. State is
    # the previous two bits; average over older pulse-memory contexts.
    for _ in range(contexts):
        pre=rng.integers(0,2,10,dtype=np.uint8)
        for state in range(4):
            hist=np.array([(state>>1)&1,state&1],dtype=np.uint8)
            for bit in (0,1):
                seq=np.r_[pre,hist,bit].astype(np.uint8)
                x=tx(seq,sps); k=len(seq)-1
                z=x[k*sps:(k+1)*sps]
                sums[state,bit]+=np.angle(z[-1]*np.conj(z[0]))/np.pi
                counts[state,bit]+=1
    return sums/counts

def export(out='soqpsk_coeffs.json'):
    g=tg_pulse(8); table=branch_templates()
    data={'pulse_q15':np.rint(g*32768).astype(int).tolist(),
          'branch_templates_q12':np.rint(table*4096).astype(int).tolist(),
          'parameters':{'rho':.70,'B':1.25,'T1':1.5,'T2':.5,'sps':8}}
    Path(out).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print('templates=',np.round(table,5).tolist())
    print('wrote',out)

if __name__=='__main__': export()
