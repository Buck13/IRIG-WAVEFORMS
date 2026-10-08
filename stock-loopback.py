"""Bounded stock DDS TX1 / dual-RX capture; always disable DDS on exit."""
from pathlib import Path
import subprocess, json, time
import numpy as np

root = Path(__file__).resolve().parent
tools = root / 'libiio-v0.26' / 'Windows-VS-2022-x64'
out = root / 'captures' / time.strftime('stock-loopback-%Y%m%d-%H%M%S')
out.mkdir(parents=True)
uri = 'ip:192.168.2.1'
phy, dds = 'ad9361-phy', 'cf-ad9361-dds-core-lpc'
log = []
def attr(device, channel, key, value=None, output=True):
    args = [str(tools/'iio_attr.exe'), '-u', uri, '-T', '5000',
            '-o' if output else '-i', '-c', device, channel, key]
    if value is not None: args.append(str(value))
    r = subprocess.run(args, capture_output=True, timeout=12)
    text = r.stdout.decode(errors='replace').strip()
    log.append({'args':args[1:], 'result':text, 'error':r.stderr.decode(errors='replace'), 'code':r.returncode})
    if r.returncode: raise RuntimeError(log[-1])
    return text
def capture(label):
    args=[str(tools/'iio_readdev.exe'), '-u',uri,'-T','5000','-b','32768',
          '-s','131072','cf-ad9361-lpc','voltage0','voltage1','voltage2','voltage3']
    r=subprocess.run(args,capture_output=True,timeout=15)
    if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
    if len(r.stdout)!=131072*8: raise RuntimeError(f'Unexpected capture size {len(r.stdout)}')
    (out/(label+'.bin')).write_bytes(r.stdout)
    return np.frombuffer(r.stdout,dtype='<i2').reshape(-1,4)[32768:]
def stats(x):
    result={}
    for k in range(2):
        iq=x[:,2*k].astype(float)+1j*x[:,2*k+1]
        iq-=iq.mean()
        f=np.fft.fftshift(np.fft.fftfreq(len(iq),1/2500000))
        p=np.abs(np.fft.fftshift(np.fft.fft(iq*np.hanning(len(iq)))))**2
        p[np.abs(f)<10000]=0
        idx=int(np.argmax(p))
        result[f'RX{k+1}']={'peak_hz':float(f[idx]),'rms_counts':float(np.sqrt(np.mean(abs(iq)**2))),
            'peak_over_median_db':float(10*np.log10(p[idx]/max(np.median(p),1e-20))),
            'clipped_components':int(np.sum(np.abs(x[:,2*k:2*k+2].astype(int))>=2047))}
    return result
results={}
cleanup=[]
try:
    for c in ('voltage0','voltage1'): attr(phy,c,'hardwaregain',-89.75)
    attr(dds,'altvoltage0','raw',0)
    for n in range(8): attr(dds,f'altvoltage{n}','scale',0)
    for output in (True,False):
        attr(phy,'voltage0','sampling_frequency',2500000,output)
        attr(phy,'voltage0','rf_bandwidth',1000000,output)
    for c in ('altvoltage0','altvoltage1'): attr(phy,c,'frequency',915000000)
    for c in ('voltage0','voltage1'):
        attr(phy,c,'gain_control_mode','manual',False)
        attr(phy,c,'hardwaregain',30,False)
    # Internal digital/RF loopback is disabled; capture the external cable path.
    r=subprocess.run([str(tools/'iio_attr.exe'),'-u',uri,'-T','5000','-D',phy,'loopback','0'],capture_output=True,timeout=12)
    if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
    for label,freq in [('off_before',None),('tone_200k',200000),('tone_350k',350000),('off_after',None)]:
        attr(dds,'altvoltage0','raw',0)
        if freq:
            for c,phase in [('altvoltage0',90000),('altvoltage2',0)]:
                attr(dds,c,'frequency',freq)
                attr(dds,c,'phase',phase)
                attr(dds,c,'scale',0.125)
            attr(phy,'voltage0','hardwaregain',-40)
            attr(dds,'altvoltage0','raw',1)
        time.sleep(0.15)
        results[label]=stats(capture(label))
        print(label,json.dumps(results[label]),flush=True)
finally:
    for device,channel,key,value in [(dds,'altvoltage0','raw',0),(phy,'voltage0','hardwaregain',-89.75),(phy,'voltage1','hardwaregain',-89.75)]:
        try: cleanup.append({'channel':channel,'attribute':key,'readback':attr(device,channel,key,value)})
        except Exception as exc: cleanup.append({'error':str(exc)})
    (out/'results.json').write_text(json.dumps({'settings':{'fs':2500000,'lo':915000000,'tx_gain_db':-40,'rx_gain_db':30,'external_atten_db':30},'captures':results,'cleanup':cleanup},indent=2))
    (out/'commands.json').write_text(json.dumps(log,indent=2))
    print('Saved:',out,flush=True)
