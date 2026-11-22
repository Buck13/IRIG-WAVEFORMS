"""Fixed-point coefficient/export helpers for the SOQPSK FPGA path."""
from pathlib import Path
import json
import numpy as np

def quantize(values, bits):
    scale=1<<bits; v=np.rint(np.asarray(values)*scale).astype(np.int64)
    return np.clip(v,-(1<<(bits)),(1<<bits)-1)

def export_vhdl(json_path='soqpsk_coeffs.json', out='soqpsk_pulse_pkg.vhd'):
    d=json.loads(Path(json_path).read_text(encoding='utf-8'))
    vals=d['pulse_q15']; lines=',\n'.join(f'    {i} => {v}' for i,v in enumerate(vals))
    text='''library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;\npackage soqpsk_pulse_pkg is\n  constant TAPS : positive := 64;\n  type tap_array is array(0 to TAPS-1) of integer range -32768 to 32767;\n  constant PULSE : tap_array := (\n%s\n  );\nend package;\n''' % lines
    Path(out).write_text(text,encoding='utf-8'); return out

if __name__=='__main__': print('wrote',export_vhdl())
