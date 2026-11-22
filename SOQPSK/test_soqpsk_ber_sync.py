import numpy as np
from soqpsk_chain import run_full

for eb in (14,18,22,26):
    vals=[]
    for fo in (0.0,0.001,0.002):
        b=np.random.default_rng(int(eb*1000+fo*1e6)).integers(0,2,256,dtype=np.uint8)
        vals.append(run_full(b,ebn0_db=eb,freq_offset=fo,phase_offset=.2,seed=9)['ber'])
    print(f'EbN0={eb}dB BER={np.mean(vals):.6f} cases={np.round(vals,6).tolist()}')
