"""Generate deterministic end-to-end vectors for cpm_viterbi_engine."""
from pathlib import Path
from viterbi_scheduler import JOBS

COS=(32767,32137,30273,27245,23170,18204,12539,6393,0,-6393,-12539,-18204,-23170,-27245,-30273,-32137,-32767,-32137,-30273,-27245,-23170,-18204,-12539,-6393,0,6393,12539,18204,23170,27245,30273,32137)
SIN=(0,6393,12539,18204,23170,27245,30273,32137,32767,32137,30273,27245,23170,18204,12539,6393,0,-6393,-12539,-18204,-23170,-27245,-30273,-32137,-32767,-32137,-30273,-27245,-23170,-18204,-12539,-6393)
INF=1 << 24

def correlations():
    return tuple((((i*37)%1000)-500, ((i*53)%1000)-500) for i in range(64))

def score(re,im,phase):
    return (re*COS[phase]+im*SIN[phase]) >> 15

def step(metrics,epoch,corr):
    out=[]; new=[]
    for destination,row in enumerate(JOBS[epoch]):
        candidates=[]
        for predecessor,corr_index,phase,_ in row:
            re,im=corr[corr_index]
            candidates.append(metrics[predecessor]-score(re,im,phase))
        winner=min(range(4),key=candidates.__getitem__)
        new.append(candidates[winner])
        out.append((destination,winner,candidates[winner]))
    return new,out

def export(path):
    corr=correlations(); metrics=[0]+[INF]*255
    metrics,rows=step(metrics,0,corr)
    lines=[]
    for pair in range(128):
        a,b=rows[2*pair],rows[2*pair+1]
        lines.append(' '.join(map(str,(*a,*b))))
    Path(path).write_text('\n'.join(lines)+'\n')

if __name__=='__main__':
    export(Path(__file__).with_name('hardware')/'viterbi_engine_vectors.txt')
