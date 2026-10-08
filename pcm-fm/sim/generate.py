"""Generate HDL constants and simulation vectors from the frozen reference."""
from pathlib import Path
import sys, hashlib, json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from pcm_fm import pn15,integer_model
manifest=json.loads((ROOT/'results/reference-sha256.json').read_text())
for name,digest in manifest.items():
    assert hashlib.sha256((ROOT/'results'/name).read_bytes()).hexdigest()==digest,name
coeff=np.loadtxt(ROOT/'results/coefficients_q17.txt',dtype=int)
lut=np.loadtxt(ROOT/'results/sine_lut_s16.txt',dtype=int)
package='''library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package pcm_fm_tables is
  type coeff_array is array(0 to 64) of integer range -131072 to 131071;
  type lut_array is array(0 to 4095) of integer range -32768 to 32767;
'''
package+='  constant COEFF : coeff_array := ('+', '.join(map(str,coeff))+');\n'
package+='  constant SINE : lut_array := (\n'+',\n'.join('    '+', '.join(map(str,lut[n:n+16])) for n in range(0,4096,16))+');\nend package;\n'
(ROOT/'hdl/pcm_fm_tables.vhd').write_text(package)
out=ROOT/'build/xsim';out.mkdir(parents=True,exist_ok=True)
patterns=[pn15(32767),np.ones(128,dtype=int),np.zeros(128,dtype=int),np.arange(256)%2,pn15(256,0x1234)]
for case,bits in enumerate(patterns):
    rows=integer_model(bits)
    with (out/f'case{case}.txt').open('w') as f:
        for symbol,row in zip(np.repeat(2*bits-1,8),rows):
            acc,inc,phase,i,q=map(int,row)
            f.write(f'{symbol} {phase:08X} {i} {q}\n')
print('Verified frozen hashes; generated constants and five test cases.')
