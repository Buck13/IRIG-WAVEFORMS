"""Offline FM discriminator and held-out PN15 check for the Pluto loopback."""
from pathlib import Path
import sys,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(sys.argv[1]);fs=2500000;sps=8;training=8192
raw=np.fromfile(p/'pcm_fm_on.bin',dtype='<i2').reshape(-1,4)[32768:]
z=raw[:,2].astype(float)+1j*raw[:,3]
# Do not subtract the signal mean: PN15 FM may have a real carrier component.
state=32767;ref=[]
for _ in range(32767):
 ref.append(1 if state&1 else -1)
 state=(state>>1)|((((state>>14)^state)&1)<<14)
ref=np.array(ref);rf=np.fft.fft(ref)
best=None
for offset in range(sps):
 # Phase change over exactly one bit; avoids summing noisy per-sample angles.
 # h=.7 keeps nominal one-bit phase changes below pi. This is not universal FM demodulation.
 starts=np.arange(offset,len(z)-sps,sps)
 freq=np.angle(z[starts+sps]*np.conj(z[starts]))*fs/(2*np.pi*sps)
 y=freq[:training];y0=y-y.mean()
 corr=np.fft.ifft(np.conj(rf)*np.fft.fft(y0,32767)).real
 lag=int(np.argmax(abs(corr)));polarity=1 if corr[lag]>=0 else -1
 score=float(abs(corr[lag])/np.sqrt(len(y)*np.dot(y0,y0)))
 if best is None or score>best['training_correlation']:
  best=dict(sample_offset=offset,lag=lag,polarity=polarity,training_correlation=score)
  f=freq
expected=ref[(np.arange(len(f))-best['lag'])%len(ref)]
# Fit only constant offset and signed gain from training; hold timing/lag fixed thereafter.
fit=np.linalg.lstsq(np.column_stack([np.ones(training),expected[:training]]),f[:training],rcond=None)[0]
cfo,gain=map(float,fit)
decisions=np.where((f-cfo)*gain>=0,1,-1)
errors=decisions!=expected
plateau=np.ones(len(expected),dtype=bool)
for shift in range(-3,4):plateau &= np.roll(expected,shift)==expected
plateau[:3]=False;plateau[-3:]=False
positive=f[plateau & (expected==1)];negative=f[plateau & (expected==-1)]
deviation=float(abs(np.median(positive)-np.median(negative))/2)
best.update(sample_rate_hz=fs,bit_rate=fs/sps,training_symbols=training,
 training_errors=int(errors[:training].sum()),held_out_symbols=len(f)-training,
 held_out_errors=int(errors[training:].sum()),total_symbols=len(f),total_errors=int(errors.sum()),
 fitted_frequency_offset_hz=cfo,fitted_symbol_gain_hz=gain,
 plateau_deviation_hz=deviation,expected_deviation_hz=.35*fs/sps,
 plateau_samples=len(positive)+len(negative),plateau_positive_median_hz=float(np.median(positive)),
 plateau_negative_median_hz=float(np.median(negative)),
 method='one-bit phase difference; 8192-symbol timing/PN alignment training; fixed held-out evaluation')
(p/'pcm-fm-analysis.json').write_text(json.dumps(best,indent=2)+'\n')
print(json.dumps(best,indent=2))
fig,ax=plt.subplots(3,1,figsize=(11,10),constrained_layout=True)
nfft=8192;w=np.hanning(nfft)
for label in ['dma_zero','pcm_fm_on','pcm_fm_off']:
 a=np.fromfile(p/(label+'.bin'),dtype='<i2').reshape(-1,4)[32768:]
 q=(a[:,2]+1j*a[:,3])/2048
 blocks=q[:len(q)//nfft*nfft].reshape(-1,nfft)
 power=np.mean(abs(np.fft.fftshift(np.fft.fft(blocks*w,axis=1),axes=1))**2,axis=0)/sum(w)**2
 ax[0].plot(np.fft.fftshift(np.fft.fftfreq(nfft,1/fs))/1000,10*np.log10(np.maximum(power,1e-16)),label=label.replace('_',' '),lw=1)
ax[0].set(xlim=(-800,800),xlabel='Offset from 915 MHz (kHz)',ylabel='dBFS / FFT bin',title='Measured RX2 spectrum');ax[0].legend()
ax[1].plot(np.arange(100),(f[:100]-cfo)/1000,'.-',label='FM discriminator (one-bit average)')
ax[1].step(np.arange(100),expected[:100]*gain/1000,where='mid',alpha=.7,label='Aligned PN15 levels')
ax[1].set(xlabel='Aligned bit index',ylabel='Frequency deviation (kHz)',title=f"PN15: {errors.sum()} errors / {len(f):,} bits; held-out errors {errors[training:].sum()}");ax[1].legend()
ax[2].hist(negative/1000,bins=70,alpha=.65,label='Long zero runs');ax[2].hist(positive/1000,bins=70,alpha=.65,label='Long one runs')
ax[2].axvline(-109.375,color='gray',ls='--');ax[2].axvline(109.375,color='gray',ls='--')
ax[2].set(xlabel='Measured frequency (kHz)',ylabel='Bit intervals',title=f'Steady-run deviation estimate: ±{deviation/1000:.3f} kHz');ax[2].legend()
for a in ax:a.grid(alpha=.2)
fig.savefig(p/'pcm-fm-result.png',dpi=150)
