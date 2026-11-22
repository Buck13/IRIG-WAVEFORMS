"""Exact-pulse, 8-bit-memory SOQPSK-TG max-log trellis reference."""
from __future__ import annotations
import numpy as np
from soqpsk_chain import tx

MEMORY=8
NSTATES=1<<MEMORY

def templates(sps=8):
    t=np.empty((NSTATES,2,sps),complex)
    for state in range(NSTATES):
        hist=np.array([(state>>(MEMORY-1-i))&1 for i in range(MEMORY)],dtype=np.uint8)
        for bit in (0,1):
            x=tx(np.r_[np.zeros(MEMORY,dtype=np.uint8),hist,bit],sps)
            z=x[-sps:]
            t[state,bit]=np.r_[0.0, np.angle(z[1:]*np.conj(z[:-1]))/np.pi]
    return t

def decode(iq,sps=8,noise_var=1.0):
    x=np.asarray(iq,complex); n=len(x)//sps; temp=templates(sps)
    pm=np.full(NSTATES,-np.inf); pm[0]=0.; surv=[]; llr=[]
    for k in range(n):
        block=x[k*sps:(k+1)*sps]
        block=np.r_[0.0, np.angle(block[1:]*np.conj(block[:-1]))/np.pi]
        nxt=np.full(NSTATES,-np.inf); prev=np.zeros(NSTATES,np.uint8); b0=-np.inf; b1=-np.inf
        for s in np.flatnonzero(np.isfinite(pm)):
            for b in (0,1):
                ns=((s<<1)|b)&(NSTATES-1)
                score=pm[s]+float(np.real(np.vdot(temp[s,b],block)))/noise_var
                if score>nxt[ns]: nxt[ns]=score; prev[ns]=s
                if b==0: b0=max(b0,score)
                else: b1=max(b1,score)
        pm=nxt; surv.append(prev); llr.append(b0-b1)
    s=int(np.argmax(pm)); bits=[]
    for k in range(n-1,-1,-1): bits.append(s&1); s=int(surv[k][s])
    return np.asarray(bits[::-1],np.uint8),np.asarray(llr)

if __name__=='__main__':
    b=np.random.default_rng(4).integers(0,2,32,dtype=np.uint8); y=tx(b)
    r,l=decode(y); print('BER=',float(np.mean(r!=b)),'LLR=',l[:8].tolist())
