"""Receive-only libiio access. May retune RX LO; never touches TX."""
import ctypes as C
import os
from pathlib import Path
import numpy as np

class Receiver:
    def __init__(self,uri='ip:192.168.2.1',rx=2,n=8192,sample_rate=None,rf_bandwidth=None):
        folder=Path(__file__).resolve().parents[1]/'libiio-v0.26/Windows-VS-2022-x64'
        self.dll_dir=os.add_dll_directory(str(folder))
        self.lib=C.CDLL(str(folder/'libiio.dll')); self.ctx=None; self.buf=None;self.n=n
        def api(name,ret,args):
            f=getattr(self.lib,name);f.restype=ret;f.argtypes=args;return f
        p=C.c_void_p
        self.create=api('iio_create_context_from_uri',p,[C.c_char_p])
        self.destroy=api('iio_context_destroy',None,[p])
        timeout=api('iio_context_set_timeout',C.c_int,[p,C.c_uint])
        self.find=api('iio_context_find_device',p,[p,C.c_char_p])
        self.channel=api('iio_device_find_channel',p,[p,C.c_char_p,C.c_bool])
        enable=api('iio_channel_enable',None,[p])
        self.attr=api('iio_channel_attr_read_longlong',C.c_int,[p,C.c_char_p,C.POINTER(C.c_longlong)])
        self.attr_write=api('iio_channel_attr_write_longlong',C.c_int,[p,C.c_char_p,C.c_longlong])
        make=api('iio_device_create_buffer',p,[p,C.c_size_t,C.c_bool])
        self.destroy_buffer=api('iio_buffer_destroy',None,[p])
        self.refill=api('iio_buffer_refill',C.c_ssize_t,[p])
        self.read=api('iio_channel_read',C.c_ssize_t,[p,p,p,C.c_size_t])
        try:
            self.ctx=self.create(uri.encode())
            if not self.ctx:raise RuntimeError('Cannot connect to IIO: '+uri)
            timeout(self.ctx,2000)
            self.phy=self.find(self.ctx,b'ad9361-phy')
            dev=self.find(self.ctx,b'cf-ad9361-lpc')
            if not dev or not self.phy:raise RuntimeError('AD9361 RX devices missing')
            self.channels=[self.channel(dev,f'voltage{k}'.encode(),False) for k in [2*(rx-1),2*(rx-1)+1]]
            if not all(self.channels):raise RuntimeError('RX channel not available')
            for ch in self.channels:enable(ch)
            if sample_rate is not None:self.set_setting('voltage0','sampling_frequency',False,sample_rate)
            if rf_bandwidth is not None:self.set_setting('voltage0','rf_bandwidth',False,rf_bandwidth)
            self.buf=make(dev,n,False)
            if not self.buf:raise RuntimeError('RX buffer unavailable; close other RX applications')
            self.arrays=[np.empty(n,dtype=np.int16) for _ in range(2)]
        except Exception:
            self.close();raise
    def setting(self,ch,key,output):
        c=self.channel(self.phy,ch.encode(),output);v=C.c_longlong()
        if not c or self.attr(c,key.encode(),C.byref(v))<0:raise RuntimeError('Cannot read '+key)
        return v.value
    def set_setting(self,ch,key,output,value):
        c=self.channel(self.phy,ch.encode(),output)
        if not c or self.attr_write(c,key.encode(),int(value))<0:
            raise RuntimeError(f'Cannot set {key} to {int(value)}')
        return self.setting(ch,key,output)
    def settings(self):
        return (self.setting('voltage0','sampling_frequency',False),
                self.setting('altvoltage0','frequency',True),
                self.setting('voltage0','rf_bandwidth',False))
    def set_rx_lo(self,frequency):
        c=self.channel(self.phy,b'altvoltage0',True)
        if not c or self.attr_write(c,b'frequency',int(frequency))<0:
            raise RuntimeError('Cannot tune RX LO')
    def capture(self):
        if self.refill(self.buf)<0:raise RuntimeError('RX timeout/disconnection; reconnect when device is ready')
        for ch,a in zip(self.channels,self.arrays):
            count=self.read(ch,self.buf,a.ctypes.data,a.nbytes)
            if count!=a.nbytes:raise RuntimeError('Unexpected RX scan size: '+str(count))
        return self.arrays[0].astype(float)+1j*self.arrays[1]
    def close(self):
        if self.buf:self.destroy_buffer(self.buf);self.buf=None
        if self.ctx:self.destroy(self.ctx);self.ctx=None
        if getattr(self,'dll_dir',None):self.dll_dir.close();self.dll_dir=None

def spectrum(z):
    w=np.hanning(len(z))
    return abs(np.fft.fftshift(np.fft.fft(z/2048*w)))**2/w.sum()**2
