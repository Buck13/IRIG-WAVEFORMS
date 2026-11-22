"""End-to-end SOQPSK-TG reference chain and noisy regression."""
from __future__ import annotations
import numpy as np
from soqpsk_frontend import tg_pulse, matched_filter, carrier_recover, timing_recover, coarse_carrier_recover, timing_align
from soqpsk_trellis import decode

def irig_precoder(bits):
    a=2*np.asarray(bits,dtype=int)-1; out=[]
    for k in range(len(a)):
        am1=a[k-1] if k else -1
        am2=a[k-2] if k>1 else -1
        out.append(((-1)**(k+1))*am1*(a[k]-am2)/2)
    return np.asarray(out)

def tx(bits,sps=8):
    alpha=irig_precoder(bits); g=tg_pulse(sps)
    # CPM frequency pulses are driven by symbol-spaced impulses, not a
    # sample-held NRZ waveform.  The 8-bit pulse response supplies memory.
    impulses=np.zeros(len(alpha)*sps)
    impulses[::sps]=alpha
    freq=np.convolve(impulses,g,mode='full')[:len(alpha)*sps]
    phase=2*np.pi*.5*np.cumsum(freq)
    return np.exp(1j*phase)

def run(bits, ebn0_db=20, freq_offset=.015, phase_offset=.25, sps=8, seed=106):
    rng=np.random.default_rng(seed); clean=tx(bits,sps); n=np.arange(len(clean))
    rotated=clean*np.exp(1j*(phase_offset+2*np.pi*freq_offset*n/sps))
    noise=(rng.normal(size=len(clean))+1j*rng.normal(size=len(clean)))*10**(-ebn0_db/20)/np.sqrt(2)
    rx=rotated+noise
    mf=matched_filter(rx,sps)
    cr=carrier_recover(mf)
    syms=timing_recover(cr,sps)
    obs=np.angle(syms[1:]*np.conj(syms[:-1]))/np.pi
    # Scale the normalized phase observations into the trellis metric range.
    decoded,llr=decode(np.clip(obs,-2,2))
    return {'clean':clean,'rx':rx,'matched':mf,'carrier_corrected':cr,
            'symbols':syms,'observations':obs,'decoded':decoded,'llr':llr,
            'ber':float(np.mean(decoded[:len(bits)-1] != bits[1:len(decoded)+1]))}

def run_full(bits, ebn0_db=20, freq_offset=.0, phase_offset=.0, sps=8, seed=106):
    """Full exact-pulse trellis after coarse carrier and timing alignment."""
    from soqpsk_full_trellis import decode as full_decode
    rng=np.random.default_rng(seed); clean=tx(np.r_[np.zeros(8,dtype=np.uint8),bits],sps)
    n=np.arange(len(clean)); rotated=clean*np.exp(1j*(phase_offset+2*np.pi*freq_offset*n/sps))
    noise=(rng.normal(size=len(clean))+1j*rng.normal(size=len(clean)))*10**(-ebn0_db/20)/np.sqrt(2)
    rx=rotated+noise; mf=matched_filter(rx,sps); cr,w,p=coarse_carrier_recover(mf,sps); aligned,off=timing_align(cr,sps)
    decoded,llr=full_decode(aligned,sps)
    usable=min(len(bits),max(0,len(decoded)-8)); ber=float(np.mean(decoded[8:8+usable]!=bits[:usable])) if usable else 1.0
    return {'decoded':decoded,'llr':llr,'ber':ber,'carrier_freq':w,'carrier_phase':p,'timing_offset':off}

if __name__ == '__main__':
    bits=np.random.default_rng(7).integers(0,2,96,dtype=np.uint8)
    r=run(bits)
    print('samples=',len(r['rx']),'symbols=',len(r['symbols']),'BER=',r['ber'])
    print('llr_range=',float(r['llr'].min()),float(r['llr'].max()))
