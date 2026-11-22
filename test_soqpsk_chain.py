import numpy as np
from soqpsk_chain import run

bits=np.random.default_rng(7).integers(0,2,96,dtype=np.uint8)
r=run(bits, ebn0_db=30, freq_offset=0.0, phase_offset=0.0)
assert len(r['matched']) == len(r['rx'])
assert len(r['llr']) == len(r['decoded'])
assert np.isfinite(r['ber'])
print('PASS end-to-end front-end/trellis chain')
print('BER=',r['ber'],'LLR=',float(r['llr'].min()),float(r['llr'].max()))
