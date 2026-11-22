import numpy as np
from soqpsk_chain import run

def sweep():
    out=[]
    for eb in (6,10,14,18,22):
        vals=[]
        for seed in range(3):
            b=np.random.default_rng(seed).integers(0,2,256,dtype=np.uint8)
            vals.append(run(b,ebn0_db=eb,freq_offset=0.0,phase_offset=0.0,seed=seed)['ber'])
        out.append((eb,float(np.mean(vals))))
    return out

if __name__=='__main__':
    print('BER sweep=',sweep())
