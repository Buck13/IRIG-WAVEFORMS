"""Verify the factorized CPM correlation-bank Viterbi metric."""
from pathlib import Path
import argparse, json, sys, time
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE)); sys.path.insert(0,str(HERE.parent))
from cpm_receiver_hardware import (ALPHABET,SPS,phase_pulse,trellis_state,
    dibit_bit_errors,quantize_iq)
from capture_demod_hardware import pn15_dibits
from metric_reduction_experiment import fixed_viterbi_positions,waveform


def base_wave(parity,b,c,d,positions):
    """Unit CPM branch with completed-phase state p removed."""
    H=4+parity; u=np.asarray(positions)/SPS
    turns=((9-H)*b/16*phase_pulse(u+1)+H*c/16*phase_pulse(u+2)
           +H*ALPHABET[d]/16*phase_pulse(u))
    return np.exp(2j*np.pi*turns)


def export_correlation_vectors(path,seed=108,cases=12):
    rng=np.random.default_rng(seed); scale=2047; positions=np.arange(0,SPS,2)
    lines=[]
    for _ in range(cases):
        parity=int(rng.integers(2)); b=int(rng.choice(ALPHABET)); c=int(rng.choice(ALPHABET)); d=int(rng.integers(4))
        w=base_wave(parity,b,c,d,positions)
        ti=np.rint(w.real*scale).astype(int); tq=np.rint(w.imag*scale).astype(int)
        r=w+0.08*(rng.normal(size=len(w))+1j*rng.normal(size=len(w)))
        ri=np.clip(np.rint(r.real*scale),-2048,2047).astype(int)
        rq=np.clip(np.rint(r.imag*scale),-2048,2047).astype(int)
        expected_re=int(np.sum(ri*ti+rq*tq)); expected_im=int(np.sum(rq*ti-ri*tq))
        for n in range(len(positions)):
            lines.append(f'{int(n==0)} {int(n==len(positions)-1)} {ri[n]} {rq[n]} {ti[n]} {tq[n]} '
                         f'{expected_re if n==len(positions)-1 else 0} {expected_im if n==len(positions)-1 else 0}')
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True); path.write_text('\n'.join(lines)+'\n')
    return path


def correlation_viterbi(received,positions,initial_state,absolute_symbol,
                        fixed=False,coefficient_bits=12,rotation_bits=16):
    """Viterbi with 64 reusable base correlations per parity.

    fixed=True quantizes RX/base IQ to signed coefficient_bits and phase
    rotations to signed rotation_bits, matching the proposed RTL boundaries.
    """
    positions=np.asarray(positions,dtype=int)
    y=np.asarray(received).reshape(-1,SPS)[:,positions]
    scale=(1<<(coefficient_bits-1))-1
    rscale=(1<<(rotation_bits-1))-1
    base={}
    history_values=(0,*map(int,ALPHABET))
    for parity in (0,1):
        for b in history_values:
            for c in history_values:
                for d in range(4):
                    w=base_wave(parity,int(b),int(c),d,positions)
                    if fixed:
                        w=(np.rint(w.real*scale).astype(np.int64)
                           +1j*np.rint(w.imag*scale).astype(np.int64))
                    base[(parity,int(b),int(c),d)]=w
    rotations=np.exp(-2j*np.pi*np.arange(32)/32)
    if fixed:
        rotations=(np.rint(rotations.real*rscale).astype(np.int64)
                   +1j*np.rint(rotations.imag*rscale).astype(np.int64))
    metrics={tuple(initial_state):0}; survivors=[]
    for n,obs in enumerate(y):
        parity=(absolute_symbol+n)&1; H=4+parity
        if fixed:
            obs=(np.rint(obs.real*scale).astype(np.int64)
                 +1j*np.rint(obs.imag*scale).astype(np.int64))
        # Only 64 complex dot products, reused by all completed-phase states.
        corr={key:np.sum(obs*np.conj(w)) for key,w in base.items()
              if key[0]==parity}
        updated={}; links={}
        for (p,b,c),old in metrics.items():
            for d,a in enumerate(ALPHABET):
                value=corr[(parity,b,c,d)]*rotations[p]
                # Common scale factors and RX/template energies do not affect ACS.
                branch=-int(np.real(value)) if fixed else -float(np.real(value))
                destination=((p+H*c)%32,int(a),b)
                candidate=old+branch
                if candidate < updated.get(destination,np.inf):
                    updated[destination]=candidate; links[destination]=((p,b,c),d)
        floor=min(updated.values()); metrics={s:m-floor for s,m in updated.items()}
        survivors.append(links)
    state=min(metrics,key=metrics.get); decoded=np.empty(len(y),dtype=np.uint8)
    for n in range(len(y)-1,-1,-1): state,decoded[n]=survivors[n][state]
    return decoded


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--capture',type=Path,default=ROOT/'Pluto-SDR/captures/cpm-h-demod-20261021-202354')
    ap.add_argument('--output',type=Path,default=HERE/'results/correlation-bank')
    args=ap.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    meta=json.loads((args.capture/'result.json').read_text())
    frames=np.fromfile(args.capture/'rx2-iq.bin',dtype='<i2').reshape(-1,4)
    count=int(meta['dibits']); start=int(meta['start_pos'])
    z=frames[start:start+count*SPS,2].astype(float)+1j*frames[start:start+count*SPS,3].astype(float)
    z=z*np.exp(-1j*meta['phase'])/meta['gain']
    pn=pn15_dibits(20_000); absolute=int(meta['absolute_symbol'])
    initial=trellis_state(pn,absolute); actual=pn[absolute:absolute+count]
    positions=np.arange(0,SPS,2)
    result={'observations_per_dibit':len(positions),'positions':positions.tolist(),
            'capture_bits':2*count,'base_correlations_per_dibit':64,
            'phase_scores_per_dibit':1024,'clock_cycles_per_dibit_100mhz':200}
    decoded={}
    for fixed in (False,True):
        name='fixed_q12_rotation_q16' if fixed else 'exact_float'
        t=time.perf_counter(); d=correlation_viterbi(z,positions,initial,absolute,fixed=fixed)
        decoded[name]=d; result[name]={'bit_errors':dibit_bit_errors(actual,d),
            'seconds':time.perf_counter()-t}
        print(name,result[name])
    result['fixed_vs_float_dibit_mismatches']=int(np.count_nonzero(decoded['fixed_q12_rotation_q16']!=decoded['exact_float']))
    result['minimum_complex_mac_lanes_100mhz']=int(np.ceil(64*len(positions)/200))
    result['minimum_phase_score_lanes_100mhz']=int(np.ceil(1024/200))
    # Compare the factored fixed-point metric with the direct squared-distance
    # fixed-point reference on common noisy sequences. Three tail dibits expose
    # the complete pulse of the final payload symbol.
    rng=np.random.default_rng(107); payload=320
    dibits=rng.integers(0,4,payload+3,dtype=np.uint8); clean=waveform(dibits)
    result['noisy_simulation']=[]
    for snr_db in (12,6,3,0):
        sigma=np.sqrt(10**(-snr_db/10)/2)
        noisy=clean+sigma*(rng.normal(size=len(clean))+1j*rng.normal(size=len(clean)))
        ni,nq=quantize_iq(noisy)
        direct=fixed_viterbi_positions(ni,nq,positions)
        factored=correlation_viterbi(noisy,positions,(0,0,0),0,fixed=True)
        row={'snr_db':snr_db,'payload_bits':2*payload,
             'direct_bit_errors':dibit_bit_errors(dibits[:payload],direct[:payload]),
             'factored_bit_errors':dibit_bit_errors(dibits[:payload],factored[:payload]),
             'direct_vs_factored_dibit_mismatches':int(np.count_nonzero(direct[:payload]!=factored[:payload]))}
        result['noisy_simulation'].append(row); print('noise',row)
    (args.output/'result.json').write_text(json.dumps(result,indent=2))
    export_correlation_vectors(HERE/'hardware/correlation_vectors.txt')
    print(json.dumps(result,indent=2))
    if any(v['bit_errors'] for k,v in result.items() if k in ('exact_float','fixed_q12_rotation_q16')):
        raise SystemExit(2)

if __name__=='__main__': main()
