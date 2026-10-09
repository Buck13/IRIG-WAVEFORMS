"""Compare legacy prototype, analog Bessel target, and selected integer FIR."""
from pathlib import Path
import hashlib,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pcm_fm import *
OUT=Path(__file__).parent/'results'
f=np.linspace(0,FS/2,16385)
w=np.exp(-2j*np.pi*f[:,None]/FS*np.arange(65))
n=np.arange(65)-32
old=2*.7/SPS*np.sinc(2*.7/SPS*n)*np.hamming(65); old/=old.sum()
h=coefficients(); q=quantized_coefficients()/(1<<FRAC)
ha=analog_response(f); hf=w@h; hq=w@q; ho=w@old
band=f<=.7*RB
magerr=np.max(abs(20*np.log10(abs(hq[band]/ha[band]))))
phaseerr=np.max(abs(np.angle(hq[band]/ha[band])))
corner=float(np.interp(-3.01029995664,20*np.log10(abs(hq))[::-1],f[::-1]))
step_old=np.convolve(np.r_[-np.ones(128),np.ones(128)],old)[:256]
step_new=np.convolve(np.r_[-np.ones(128),np.ones(128)],q)[:256]
metrics=dict(reference='RCC 106-22 Chapter 2, Table 2-3, sixth-order Bessel',
    target_corner_hz=.7*RB,quantized_half_power_corner_hz=corner,
    passband_max_magnitude_error_db=float(magerr),passband_max_phase_error_rad=float(phaseerr),
    old_transition_peak=float(max(step_old[128:])),new_transition_peak=float(max(step_new[128:])),
    dc_group_delay_samples=float(np.arange(65)@q),fir_abs_sum_q17=int(abs(quantized_coefficients()).sum()))
assert abs(corner/(.7*RB)-1)<.001
assert magerr<.01 and phaseerr<.002
assert metrics['new_transition_peak']<1.02
assert np.max(abs(quantized_coefficients()))<2**17
fig,ax=plt.subplots(2,2,figsize=(12,8),constrained_layout=True)
for response,label in [(ho,'old sinc'),(ha,'analog Bessel'),(hq,'quantized FIR')]:
    ax[0,0].plot(f/RB,20*np.log10(np.maximum(abs(response),1e-8)),label=label)
    gd=-np.gradient(np.unwrap(np.angle(response)),2*np.pi*f/FS)
    ax[0,1].plot(f/RB,gd,label=label)
ax[0,0].set(xlim=(0,2),ylim=(-70,2),xlabel='frequency / bit rate',ylabel='magnitude (dB)'); ax[0,0].legend(); ax[0,0].axvline(.7,color='gray',ls='--')
ax[0,1].set(xlim=(0,1),ylim=(0,35),xlabel='frequency / bit rate',ylabel='group delay (samples)')
ax[1,0].plot((np.arange(256)-128)/SPS,step_old,label='old'); ax[1,0].plot((np.arange(256)-128)/SPS,step_new,label='selected'); ax[1,0].set(xlim=(-2,10),xlabel='bit intervals from transition',ylabel='frequency command'); ax[1,0].legend()
bits=pn15(8192); x=np.repeat(2*bits-1,SPS)
for taps,label in [(old,'old'),(q,'selected')]:
    shaped=np.convolve(x,taps)[:len(x)]
    z=np.exp(2j*np.pi*DEVIATION/FS*np.cumsum(shaped))[512:]
    p=abs(np.fft.fftshift(np.fft.fft(z*np.hanning(len(z)))))**2
    ax[1,1].plot(np.fft.fftshift(np.fft.fftfreq(len(z),1/FS))/RB,10*np.log10(np.maximum(p/p.max(),1e-12)),label=label,alpha=.7)
ax[1,1].set(xlim=(-2.5,2.5),ylim=(-100,0),xlabel='baseband frequency / bit rate',ylabel='relative periodogram (dB)'); ax[1,1].legend()
fig.savefig(OUT/'filter-comparison.png',dpi=140)
(OUT/'filter-validation.json').write_text(json.dumps(metrics,indent=2)+'\n')
manifest={name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['coefficients_q17.txt','sine_lut_s16.txt','hdl_vectors.csv']}
(OUT/'reference-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
