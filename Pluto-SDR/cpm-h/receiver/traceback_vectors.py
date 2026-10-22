"""Generate deterministic survivor-memory and traceback vectors."""
from pathlib import Path
import random
from viterbi_scheduler import JOBS

DEPTH=32
SYMBOLS=40

def export(hardware):
    rng=random.Random(113)
    survivors=[[rng.randrange(4) for _ in range(256)] for _ in range(SYMBOLS)]
    best=[rng.randrange(256) for _ in range(SYMBOLS)]
    writes=[]
    for n in range(SYMBOLS):
        for pair in range(128):
            d0=2*pair;d1=d0+1
            m0=0 if d0==best[n] else 1000+d0
            m1=0 if d1==best[n] else 1000+d1
            writes.append((n,n&3,d0,survivors[n][d0],m0,d1,survivors[n][d1],m1,int(pair==127)))
    decoded=[]
    for n in range(DEPTH-1,SYMBOLS):
        state=best[n]
        for offset in range(DEPTH):
            row=n-offset
            if offset==DEPTH-1: decoded.append((n,(state>>2)&3))
            choice=survivors[row][state]
            state=JOBS[row&3][state][choice][0]
    hardware=Path(hardware);hardware.mkdir(parents=True,exist_ok=True)
    (hardware/'traceback_write_vectors.txt').write_text('\n'.join(' '.join(map(str,r)) for r in writes)+'\n')
    (hardware/'traceback_decoded_vectors.txt').write_text('\n'.join(' '.join(map(str,r)) for r in decoded)+'\n')

if __name__=='__main__': export(Path(__file__).with_name('hardware'))
