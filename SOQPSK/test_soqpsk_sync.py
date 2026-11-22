import numpy as np
from soqpsk_chain import run_full

b=np.random.default_rng(8).integers(0,2,128,dtype=np.uint8)
r=run_full(b,ebn0_db=24,freq_offset=.002,phase_offset=.2)
print('sync/full-trellis BER=',r['ber'],'freq=',r['carrier_freq'],'timing=',r['timing_offset'])
assert np.isfinite(r['ber']) and np.all(np.isfinite(r['llr']))
