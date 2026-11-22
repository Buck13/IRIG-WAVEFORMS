"""SOQPSK-TG front-end reference: exact pulse, matched filter, carrier/timing loops.

The constants and pulse/window equations follow IRIG 106-22 Chapter 2,
Table 2-4 and Eqs. 2-19/2-20: rho=.70, B=1.25, T1=1.5, T2=.5, L=8 bits.
"""
from __future__ import annotations
import numpy as np

RHO, B, T1, T2 = .70, 1.25, 1.5, .5

def tg_pulse(sps=8):
    # Centered support [-4Tb, 4Tb], sampled at the middle of each interval.
    u=(np.arange(8*sps)+.5)/sps-4.0
    x=B*u/2.0
    den=1.0-4.0*(RHO*x)**2
    sinc=np.sinc(B*u/2.0)
    core=(sinc*sinc)*np.cos(np.pi*RHO*x)/np.where(np.abs(den)<1e-10,1.0,den)
    w=np.ones_like(u); z=np.abs(u)/2.0
    ramp=(z>T1)&(z<=T1+T2)
    w[ramp]=.5+.5*np.cos(np.pi*(z[ramp]-T1)/T2)
    w[z>T1+T2]=0.0
    g=core*w
    g *= .5/np.sum(g)
    return g

def matched_filter(iq, sps=8):
    g=tg_pulse(sps)
    return np.convolve(np.asarray(iq,complex), g[::-1], mode='same')

def carrier_recover(iq, loop_bw=.01):
    """Decision-directed Costas-style phase/frequency correction."""
    x=np.asarray(iq,complex); out=np.empty_like(x); phase=0.; freq=0.
    for n,v in enumerate(x):
        y=v*np.exp(-1j*phase); out[n]=y
        err=np.sign(y.real)*y.imag-np.sign(y.imag)*y.real
        freq += loop_bw*err; phase += freq + 2*loop_bw*err
    return out

def coarse_carrier_recover(iq, sps=8):
    """Feed-forward frequency/phase correction from the mean sample phase slope."""
    x=np.asarray(iq,complex); d=np.angle(x[1:]*np.conj(x[:-1]))
    # The pulse has zero mean frequency; robust median rejects transitions.
    w=float(np.median(d)); n=np.arange(len(x)); y=x*np.exp(-1j*w*n)
    phase=float(np.angle(np.mean(y[:min(len(y),4*sps)])))
    return y*np.exp(-1j*phase), w, phase

def timing_align(iq, sps=8, search=16):
    """Choose a fractional sample offset maximizing matched-filter energy."""
    x=np.asarray(iq,complex); best=None
    def interp(k):
        j=int(k); f=k-j
        return x[j]*(1-f)+x[j+1]*f
    for q in range(search):
        off=q/search; z=np.asarray([interp(k*sps+off) for k in range((len(x)-2)//sps)])
        score=float(np.mean(np.abs(z)**2))
        if best is None or score>best[0]: best=(score,off)
    off=best[1]; return np.asarray([interp(k+off) for k in range(len(x)-1)]), off

def timing_recover(iq, sps=8, gain=.01):
    """Simple Gardner timing loop; returns interpolated symbol-rate samples."""
    x=np.asarray(iq,complex); mu=0.; i=0; out=[]
    while i + mu + sps + 1 < len(x):
        def interp(k):
            j=int(k); f=k-j
            return x[j]*(1-f)+x[j+1]*f
        mid=interp(i+mu+sps/2); cur=interp(i+mu); nxt=interp(i+mu+sps)
        err=np.real(np.conj(mid)*(nxt-cur)); out.append(cur)
        mu += gain*err; step=sps+mu; i += int(step); mu=step-int(step)
    return np.asarray(out)

if __name__ == '__main__':
    g=tg_pulse(); print('pulse_samples=',len(g),'area=',float(g.sum()),'peak=',float(g.max()))
