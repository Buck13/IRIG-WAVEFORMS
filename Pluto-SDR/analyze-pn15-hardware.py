from pathlib import Path
import sys,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(sys.argv[1]); fs=2500000
a=np.fromfile(p/'pn15_on.bin',dtype='<i2').reshape(-1,4)
z=a[32768:,2].astype(float)+1j*a[32768:,3]
z-=z.mean()
state=32767; ref=[]
for _ in range(32767):
    ref.append(1 if state&1 else -1)
    state=(state>>1)|((((state>>14)^state)&1)<<14)
ref=np.array(ref); rf=np.fft.fft(ref)
best=None
for sps in [1,2,4,8,16,32,64,128]:
    for offset in range(sps):
        n=min(8192,(len(z)-offset)//sps)
        y=z[offset:offset+n*sps].reshape(n,sps).mean(axis=1)
        corr=np.fft.ifft(np.conj(rf)*np.fft.fft(y,32767))
        lag=int(np.argmax(abs(corr))); score=float(abs(corr[lag])/np.sqrt(n*np.vdot(y,y).real))
        if best is None or score>best['normalized_correlation']:
            best={'sps':sps,'sample_offset':offset,'lag':lag,'normalized_correlation':score,'symbols':n}
            by=y
# Correlation convention: observed symbol n matches ref[(n-lag) mod period].
expected=ref[(np.arange(len(by))-best['lag'])%len(ref)]
gain=np.mean(by*expected)
rot=by*np.exp(-1j*np.angle(gain))
best['symbol_errors']=int(np.sum(np.where(rot.real>=0,1,-1)!=expected))
sps=best['sps']; offset=best['sample_offset']
total=(len(z)-offset)//sps
all_symbols=z[offset:offset+total*sps].reshape(total,sps).mean(axis=1)
all_expected=ref[(np.arange(total)-best['lag'])%len(ref)]
all_decisions=np.where((all_symbols*np.exp(-1j*np.angle(gain))).real>=0,1,-1)
best['held_out_symbols']=total-len(by)
best['held_out_errors']=int(np.sum(all_decisions[len(by):]!=all_expected[len(by):]))
best['total_symbols']=total
best['total_errors']=int(np.sum(all_decisions!=all_expected))
best['symbol_rate']=fs/best['sps']
(p/'pn15-analysis.json').write_text(json.dumps(best,indent=2))
print(json.dumps(best),flush=True)
fig,ax=plt.subplots(2,1,figsize=(11,7),constrained_layout=True)
nfft=8192; w=np.hanning(nfft)
for label,color in [('dma_zero','#89939f'),('pn15_on','#087f8c'),('pn15_off','#d56a19')]:
    x=np.fromfile(p/(label+'.bin'),dtype='<i2').reshape(-1,4)[32768:]
    q=(x[:,2]+1j*x[:,3])/2048
    q=q[:len(q)//nfft*nfft].reshape(-1,nfft); q-=q.mean(axis=1,keepdims=True)
    power=np.mean(abs(np.fft.fftshift(np.fft.fft(q*w,axis=1),axes=1))**2,axis=0)/sum(w)**2
    ax[0].plot(np.fft.fftshift(np.fft.fftfreq(nfft,1/fs))/1000,10*np.log10(np.maximum(power,1e-16)),label=label.replace('_',' '),color=color,lw=1)
ax[0].set(xlim=(-1000,1000),xlabel='Offset from 915 MHz (kHz)',ylabel='dBFS / FFT bin',title='RX2 measured spectrum — FPGA source on and off')
ax[0].legend(); ax[0].grid(alpha=.2)
ax[1].plot(rot.real[:100]/abs(gain),'.-',lw=.8,label='Received symbols (phase aligned)')
ax[1].step(np.arange(100),expected[:100],where='mid',alpha=.65,label='Expected PN15')
ax[1].set(xlabel='Aligned symbol index',ylabel='Normalized amplitude',title=f"PN15 check: {best['total_errors']} errors / {total:,} symbols; {best['symbol_rate']:,.0f} symbols/s")
ax[1].legend(); ax[1].grid(alpha=.2)
fig.savefig(p/'pn15-result.png',dpi=150)
