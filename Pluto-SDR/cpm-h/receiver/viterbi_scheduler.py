"""Two-lane schedule and ROM exporter for the 256-state steady CPM trellis."""
from pathlib import Path
import numpy as np

ALPHABET=(-3,-1,1,3)

def advance(states,parity):
    H=4+parity; out=set()
    for p,b,c in states:
        for a in ALPHABET: out.add(((p+H*c)%32,a,b))
    return out

def steady_state_sets():
    states={(0,0,0)}
    for n in range(4): states=advance(states,n&1)
    result=[]
    for epoch in range(4):
        assert len(states)==256
        result.append(tuple(sorted(states)))
        states=advance(states,epoch&1)
    assert set(states)==set(result[0])
    return tuple(result)

STATES=steady_state_sets()

def jobs(epoch):
    src=STATES[epoch]; dst=STATES[(epoch+1)&3]
    src_index={s:i for i,s in enumerate(src)}
    H=4+(epoch&1); rows=[]
    for destination in dst:
        matches=[]
        for i,(p,b,c) in enumerate(src):
            for d,a in enumerate(ALPHABET):
                if ((p+H*c)%32,a,b)==destination:
                    corr=ALPHABET.index(b)*16+ALPHABET.index(c)*4+d
                    matches.append((i,corr,p,d))
        assert len(matches)==4
        # State indices are arranged with older-symbol c as the low two bits.
        # Order predecessors by that bank so candidate k reads metric bank k.
        rows.append(tuple(sorted(matches,key=lambda x:x[0]%4)))
    return tuple(rows)

JOBS=tuple(jobs(e) for e in range(4))

def scheduled_update(old_metrics,branch_cost,epoch):
    """Return 256 new metrics and two-bit predecessor survivors."""
    new=np.empty(256,dtype=np.int64); survivor=np.empty(256,dtype=np.uint8)
    for destination,row in enumerate(JOBS[epoch]):
        candidates=[int(old_metrics[pred])+int(branch_cost[pred,d])
                    for pred,_,_,d in row]
        survivor[destination]=int(np.argmin(candidates));new[destination]=min(candidates)
    return new,survivor

def direct_update(old_metrics,branch_cost,epoch):
    dst_index={s:i for i,s in enumerate(STATES[(epoch+1)&3])}
    H=4+(epoch&1); new=np.full(256,np.iinfo(np.int64).max,dtype=np.int64)
    for i,(p,b,c) in enumerate(STATES[epoch]):
        for d,a in enumerate(ALPHABET):
            j=dst_index[((p+H*c)%32,a,b)]
            new[j]=min(new[j],int(old_metrics[i])+int(branch_cost[i,d]))
    return new

def export(directory):
    root=Path(directory);root.mkdir(parents=True,exist_ok=True)
    pred=[];corr=[];phase=[]
    for epoch in range(4):
        for row in JOBS[epoch]:
            for pi,ci,ph,_ in row: pred.append(pi);corr.append(ci);phase.append(ph)
    def body(values): return ',\n'.join(f'    {i} => {v}' for i,v in enumerate(values))
    pkg=f'''library ieee;
use ieee.std_logic_1164.all;
package cpm_schedule_pkg is
  constant SCHEDULE_WORDS:positive:=4096;
  type pred_rom_t is array(0 to SCHEDULE_WORDS-1) of integer range 0 to 255;
  type corr_rom_t is array(0 to SCHEDULE_WORDS-1) of integer range 0 to 63;
  type phase_rom_t is array(0 to SCHEDULE_WORDS-1) of integer range 0 to 31;
  constant PRED_ROM:pred_rom_t := (\n{body(pred)}\n  );
  constant CORR_ROM:corr_rom_t := (\n{body(corr)}\n  );
  constant PHASE_ROM:phase_rom_t := (\n{body(phase)}\n  );
end package;
'''
    (root/'cpm_schedule_pkg.vhd').write_text(pkg)
    lines=[]
    for epoch in range(4):
        for cycle in range(128):
            fields=[epoch,cycle]
            for lane in range(2):
                dest=2*cycle+lane;fields.append(dest)
                for pi,ci,ph,_ in JOBS[epoch][dest]: fields += [pi,ci,ph]
            lines.append(' '.join(map(str,fields)))
    (root/'scheduler_vectors.txt').write_text('\n'.join(lines)+'\n')
    return root

if __name__=='__main__':
    rng=np.random.default_rng(110)
    for epoch in range(4):
        old=rng.integers(0,1<<30,256,dtype=np.int64)
        costs=rng.integers(-(1<<20),1<<20,(256,4),dtype=np.int64)
        scheduled,_=scheduled_update(old,costs,epoch)
        assert np.array_equal(scheduled,direct_update(old,costs,epoch))
    print('PASS: four epoch schedules exactly match direct trellis updates')
    print(export(Path(__file__).parent/'hardware'))
