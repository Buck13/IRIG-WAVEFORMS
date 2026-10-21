"""Choose CPM-H Viterbi observation count using real and simulated IQ."""
from pathlib import Path
import argparse, json, sys, time
import numpy as np
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
from cpm_receiver_hardware import (ALPHABET, IQ_PEAK, SPS, branch_bank,
    dibit_bit_errors, quantize_iq, trellis_state)
from capture_demod_hardware import pn15_dibits


def fixed_viterbi_positions(iq_i, iq_q, positions, initial_state=(0,0,0),
                            absolute_symbol=0):
    """Golden integer Viterbi using selected sample positions per dibit."""
    positions = np.asarray(positions, dtype=int)
    ri = np.asarray(iq_i, dtype=np.int32).reshape(-1, SPS)[:, positions]
    rq = np.asarray(iq_q, dtype=np.int32).reshape(-1, SPS)[:, positions]
    metrics = {tuple(initial_state): 0}; survivors=[]
    for n, (oi, oq) in enumerate(zip(ri, rq)):
        updated={}; links={}
        for state, old in metrics.items():
            ti,tq,destinations = branch_bank((absolute_symbol+n)&1,state,SPS)
            di=ti[:,positions].astype(np.int32)-oi[None,:]
            dq=tq[:,positions].astype(np.int32)-oq[None,:]
            bm=np.sum(di.astype(np.int64)**2+dq.astype(np.int64)**2,axis=1)
            for dibit,destination in enumerate(destinations):
                candidate=old+int(bm[dibit])
                if candidate < updated.get(destination,1<<63):
                    updated[destination]=candidate
                    links[destination]=(state,dibit)
        floor=min(updated.values())
        metrics={s:m-floor for s,m in updated.items()}
        survivors.append(links)
    state=min(metrics,key=metrics.get)
    decoded=np.empty(len(ri),dtype=np.uint8)
    for n in range(len(ri)-1,-1,-1):
        state,decoded[n]=survivors[n][state]
    return decoded


def waveform(dibits):
    state=(0,0,0); chunks=[]
    for n,d in enumerate(dibits):
        ti,tq,dest=branch_bank(n&1,state,SPS)
        chunks.append(ti[d].astype(float)/IQ_PEAK+1j*tq[d]/IQ_PEAK)
        state=dest[d]
    return np.concatenate(chunks)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--capture',type=Path,default=ROOT/'Pluto-SDR/captures/cpm-h-demod-20261021-202354')
    ap.add_argument('--output',type=Path,default=HERE/'results/metric-reduction')
    ap.add_argument('--sim-dibits',type=int,default=160)
    args=ap.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    configs={k:np.arange(0,SPS,SPS//k) for k in (32,16,8,4)}
    result={'sample_rate_hz':16_000_000,'bit_rate_bps':1_000_000,
            'fpga_clock_hz':100_000_000,'configs':{}}

    # The capture metadata records synchronization, phase/gain correction, and
    # exact absolute PN15/trellis position from the previous acquisition step.
    meta=json.loads((args.capture/'result.json').read_text())
    frames=np.fromfile(args.capture/'rx2-iq.bin',dtype='<i2').reshape(-1,4)
    count=int(meta['dibits']); start=int(meta['start_pos'])
    z=frames[start:start+count*SPS,2].astype(float)+1j*frames[start:start+count*SPS,3].astype(float)
    z=z*np.exp(-1j*meta['phase'])/meta['gain']
    ci,cq=quantize_iq(z)
    pn=pn15_dibits(20_000); absolute=int(meta['absolute_symbol'])
    initial=trellis_state(pn,absolute); actual=pn[absolute:absolute+count]
    for k,pos in configs.items():
        t=time.perf_counter(); decoded=fixed_viterbi_positions(ci,cq,pos,initial,absolute)
        errors=dibit_bit_errors(actual,decoded)
        result['configs'][str(k)]={'positions':pos.tolist(),'capture_bits':2*count,
            'capture_bit_errors':errors,'capture_ber':errors/(2*count),
            'python_seconds':time.perf_counter()-t,
            'branches_per_dibit':1024,'sample_distances_per_dibit':1024*k,
            'minimum_branch_lanes_at_100mhz':int(np.ceil(1024/200)),
            'minimum_sample_lanes_at_100mhz':int(np.ceil(1024*k/200))}
        print(f'capture K={k}: {errors}/{2*count} bit errors')

    rng=np.random.default_rng(106)
    # Three trailing symbols expose the complete pulse response of the final
    # payload symbols. Decode them, but exclude them from the BER count.
    dibits=rng.integers(0,4,args.sim_dibits+3,dtype=np.uint8)
    clean=waveform(dibits)
    for snr_db in (12,6,3,0):
        sigma=np.sqrt(10**(-snr_db/10)/2)
        noisy=clean+sigma*(rng.normal(size=len(clean))+1j*rng.normal(size=len(clean)))
        si,sq=quantize_iq(noisy)
        for k,pos in configs.items():
            decoded=fixed_viterbi_positions(si,sq,pos)
            errors=dibit_bit_errors(dibits[:args.sim_dibits],decoded[:args.sim_dibits])
            result['configs'][str(k)].setdefault('simulation',[]).append({
                'snr_db':snr_db,'bits':2*args.sim_dibits,'bit_errors':errors,
                'ber':errors/(2*args.sim_dibits)})
            print(f'sim {snr_db:2d} dB K={k:2d}: {errors}/{2*args.sim_dibits}')

    (args.output/'result.json').write_text(json.dumps(result,indent=2))
    ks=np.array([32,16,8,4])
    fig,ax=plt.subplots(1,2,figsize=(11,4.5),constrained_layout=True)
    ax[0].bar(ks.astype(str),[result['configs'][str(k)]['capture_bit_errors'] for k in ks])
    ax[0].set(xlabel='IQ observations per dibit',ylabel='Bit errors / 1024',
              title='Saved Pluto loopback capture'); ax[0].grid(axis='y',alpha=.25)
    for k in ks:
        sim=result['configs'][str(k)]['simulation']
        ax[1].semilogy([x['snr_db'] for x in sim],
                       [max(x['ber'],1/(2*x['bits'])) for x in sim],'-o',label=f'{k} observations')
    ax[1].set(xlabel='Complex-sample SNR (dB)',ylabel='BER (zero shown at 1/(2N))',
              title=f'Controlled simulation, {2*args.sim_dibits} bits');
    ax[1].grid(True,which='both',alpha=.25); ax[1].legend()
    fig.savefig(args.output/'metric-reduction.png',dpi=160); plt.close(fig)
    print(args.output/'result.json')

if __name__=='__main__': main()
