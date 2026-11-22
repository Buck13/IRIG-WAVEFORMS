import numpy as np
from soqpsk_chain import tx
from soqpsk_full_trellis import decode

b=np.random.default_rng(4).integers(0,2,64,dtype=np.uint8)
seq=np.r_[np.zeros(8,dtype=np.uint8),b]
r,llr=decode(tx(seq))
assert np.array_equal(r[8:],b), f'full trellis BER={np.mean(r[8:]!=b)}'
assert np.all(np.isfinite(llr))
print('PASS exact-pulse 256-state trellis, BER=0 at high SNR')
