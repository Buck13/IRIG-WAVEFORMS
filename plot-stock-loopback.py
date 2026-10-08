from pathlib import Path
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

p=Path(sys.argv[1])
fig,axes=plt.subplots(2,1,figsize=(11,7),sharex=True,constrained_layout=True)
n=8192
w=np.hanning(n)
f=np.fft.fftshift(np.fft.fftfreq(n,1/2500000))/1000
for label,color in [('off_before','#89939f'),('tone_200k','#087f8c'),('tone_350k','#d56a19')]:
    a=np.fromfile(p/(label+'.bin'),dtype='<i2').reshape(-1,4)[32768:]
    for k,ax in enumerate(axes):
        z=(a[:,k*2]+1j*a[:,k*2+1])/2048
        z=z[:len(z)//n*n].reshape(-1,n)
        z-=z.mean(axis=1,keepdims=True)
        power=np.mean(abs(np.fft.fftshift(np.fft.fft(z*w,axis=1),axes=1))**2,axis=0)/sum(w)**2
        ax.plot(f,10*np.log10(np.maximum(power,1e-16)),color=color,label=label.replace('_',' '),lw=1)
        ax.set_title(f'RX{k+1}'+(' — connected through 30 dB attenuator' if k else ' — comparison channel'))
        ax.set_ylabel('dBFS / FFT bin')
        ax.grid(alpha=.2)
        ax.set_ylim(-110,-40)
        ax.legend(loc='upper right')
axes[-1].set_xlim(-500,500)
axes[-1].set_xlabel('Frequency offset from 915 MHz (kHz)')
fig.suptitle('Measured Pluto TX1 → RX2 loopback\nStock DDS tones • 2.5 MS/s • TX attenuation 40 dB • RX gain 30 dB')
fig.savefig(p/'spectrum.png',dpi=150)
print(p/'spectrum.png')
