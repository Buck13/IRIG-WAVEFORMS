"""Golden vectors and arithmetic check for the four-predecessor CPM ACS lane."""
from pathlib import Path
import numpy as np

PHASE_SCALE=32767
COS=np.rint(np.cos(2*np.pi*np.arange(32)/32)*PHASE_SCALE).astype(np.int64)
SIN=np.rint(np.sin(2*np.pi*np.arange(32)/32)*PHASE_SCALE).astype(np.int64)

def phase_score(correlation_re,correlation_im,p):
    # Re(C * exp(-j*2*pi*p/32)) = Cre*cos + Cim*sin.
    return (int(correlation_re)*int(COS[p])+int(correlation_im)*int(SIN[p])) >> 15

def acs4(old_metrics,corr_re,corr_im,phase):
    candidates=[int(old_metrics[k])-phase_score(corr_re[k],corr_im[k],phase[k]) for k in range(4)]
    winner=int(np.argmin(candidates))
    return candidates[winner],winner,candidates

def export(path,cases=256,seed=109):
    rng=np.random.default_rng(seed); lines=[]
    for _ in range(cases):
        old=rng.integers(0,1<<30,4,dtype=np.int64)
        cre=rng.integers(-(1<<17),1<<17,4,dtype=np.int64)
        cim=rng.integers(-(1<<17),1<<17,4,dtype=np.int64)
        phase=rng.integers(0,32,4,dtype=np.int64)
        metric,winner,_=acs4(old,cre,cim,phase)
        fields=[]
        for k in range(4): fields += [old[k],cre[k],cim[k],phase[k]]
        fields += [metric,winner]
        lines.append(' '.join(str(int(x)) for x in fields))
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True);path.write_text('\n'.join(lines)+'\n')
    return path

if __name__=='__main__': print(export(Path(__file__).parent/'hardware/phase_acs_vectors.txt'))
