"""Custom GPIO source selection with zero-filled cyclic DMA, bounded RX capture."""
from pathlib import Path
import ctypes as C
import os, subprocess, time, json
import numpy as np
root=Path(__file__).resolve().parent
bin=root/'libiio-v0.26/Windows-VS-2022-x64'
out=root/'captures'/time.strftime('pcm-fm-hardware-%Y%m%d-%H%M%S')
out.mkdir(parents=True)
uri='ip:192.168.2.1'
hostkey='SHA256:o4ZgModBtzjIAm83AMAXtVk8XvQlkArIZtxxa2zXJ2Q'
def ssh(cmd):
    p=subprocess.run(['C:/Program Files (x86)/PuTTY/plink.exe','-ssh','-batch','-hostkey',hostkey,'-pw','analog','root@192.168.2.1',cmd],capture_output=True,timeout=15)
    if p.returncode: raise RuntimeError(p.stderr.decode(errors='replace'))
    return p.stdout.decode().strip()
def attr(dev,ch,key,value,output=True):
    p=subprocess.run([str(bin/'iio_attr.exe'),'-u',uri,'-T','5000','-o' if output else '-i','-c',dev,ch,key,str(value)],capture_output=True,timeout=12)
    if p.returncode: raise RuntimeError(p.stderr.decode(errors='replace'))
def capture(label):
    n=1048576
    p=subprocess.run([str(bin/'iio_readdev.exe'),'-u',uri,'-T','5000','-b','32768','-s',str(n),'cf-ad9361-lpc','voltage0','voltage1','voltage2','voltage3'],capture_output=True,timeout=30)
    if p.returncode or len(p.stdout)!=n*8: raise RuntimeError(f'Capture: {len(p.stdout)} bytes {p.stderr!r}')
    (out/(label+'.bin')).write_bytes(p.stdout)
    a=np.frombuffer(p.stdout,dtype='<i2').reshape(-1,4)[32768:]
    result={f'RX{k+1}':{'rms_counts':float(np.sqrt(np.mean(np.abs(a[:,k*2].astype(float)+1j*a[:,k*2+1])**2))), 'clipped':int(np.sum(abs(a[:,2*k:2*k+2].astype(int))>=2047))} for k in range(2)}
    print(label,result,flush=True)
    return result
os.add_dll_directory(str(bin))
lib=C.CDLL(str(bin/'libiio.dll'))
def api(name,ret,args):
    fn=getattr(lib,name); fn.restype=ret; fn.argtypes=args; return fn
ptr=C.c_void_p
create=api('iio_create_context_from_uri',ptr,[C.c_char_p])
destroy=api('iio_context_destroy',None,[ptr])
find=api('iio_context_find_device',ptr,[ptr,C.c_char_p])
channel=api('iio_device_find_channel',ptr,[ptr,C.c_char_p,C.c_bool])
enable=api('iio_channel_enable',None,[ptr])
buffer_create=api('iio_device_create_buffer',ptr,[ptr,C.c_size_t,C.c_bool])
buffer_destroy=api('iio_buffer_destroy',None,[ptr])
start=api('iio_buffer_start',ptr,[ptr]); end=api('iio_buffer_end',ptr,[ptr])
push=api('iio_buffer_push',C.c_ssize_t,[ptr])
ctx=buf=None
results={}
try:
    # Kernel firmware attribute is write-only. Run immediately after verified load;
    # a saved log/hash alone cannot identify an independently reconfigured FPGA.
    load_log=ssh('cat /tmp/pcm-fm-load.log')
    assert 'TEMPORARY_LOAD_DONE' in load_log, 'PCM-FM load completion missing'
    assert ssh('sha256sum /lib/firmware/pluto_pcm_fm.bit.bin').split()[0] == '7d4c06da4e1387f05e5d982299e4db2ff012f35cabd4c784a9aedfcd089a6fbd', 'Firmware hash mismatch'
    print(ssh('cat /sys/class/fpga_manager/fpga0/state; devmem 0x41210000 32 0; echo fdd > /sys/bus/iio/devices/iio:device0/ensm_mode'),flush=True)
    for ch in ['voltage0','voltage1']: attr('ad9361-phy',ch,'hardwaregain',-89.75)
    for output in [True,False]:
        attr('ad9361-phy','voltage0','sampling_frequency',2500000,output)
        attr('ad9361-phy','voltage0','rf_bandwidth',1000000,output)
    for ch in ['altvoltage0','altvoltage1']: attr('ad9361-phy',ch,'frequency',915000000)
    for ch in ['voltage0','voltage1']:
        attr('ad9361-phy',ch,'gain_control_mode','manual',False)
        attr('ad9361-phy',ch,'hardwaregain',30,False)
    attr('cf-ad9361-dds-core-lpc','altvoltage0','raw',0)
    ctx=create(uri.encode())
    if not ctx: raise RuntimeError('No IIO context')
    dev=find(ctx,b'cf-ad9361-dds-core-lpc')
    for n in range(4):
        c=channel(dev,f'voltage{n}'.encode(),True)
        if not c: raise RuntimeError('Missing TX scan channel')
        enable(c)
    buf=buffer_create(dev,4096,True)
    if not buf: raise RuntimeError('Cyclic TX allocation failed')
    C.memset(start(buf),0,end(buf)-start(buf))
    if push(buf)<0: raise RuntimeError('Cyclic TX push failed')
    attr('ad9361-phy','voltage0','hardwaregain',-40)
    results['dma_zero']=capture('dma_zero')
    print('PCM-FM selector',ssh('devmem 0x41210000 32 1; devmem 0x41210000 32'),flush=True)
    time.sleep(.2)
    results['pcm_fm_on']=capture('pcm_fm_on')
    ssh('devmem 0x41210000 32 0')
    results['pcm_fm_off']=capture('pcm_fm_off')
finally:
    errors=[]
    try: ssh('devmem 0x41210000 32 0')
    except Exception as e: errors.append(str(e))
    for ch in ['voltage0','voltage1']:
        try: attr('ad9361-phy',ch,'hardwaregain',-89.75)
        except Exception as e: errors.append(str(e))
    if buf: buffer_destroy(buf)
    if ctx: destroy(ctx)
    try: attr('cf-ad9361-dds-core-lpc','altvoltage0','raw',0)
    except Exception as e: errors.append(str(e))
    (out/'results.json').write_text(json.dumps({'captures':results,'cleanup_errors':errors,'fs':2500000,'lo':915000000,'tx_gain':-40,'rx_gain':30},indent=2))
    print('Saved',out,'cleanup errors',errors,flush=True)
