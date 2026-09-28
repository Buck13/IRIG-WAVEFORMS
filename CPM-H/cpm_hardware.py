"""Clocked ARTM multi-h CPM teaching model and VHDL table/vector exporter."""
from pathlib import Path
import numpy as np

SPS = 32
PHASE_BITS = 24
MODULUS = 1 << PHASE_BITS

def q(u):
    v = np.clip(np.asarray(u, dtype=float), 0, 3)
    return v / 6 - np.sin(2*np.pi*v/3) / (4*np.pi)

def g(u):
    u = np.asarray(u, dtype=float)
    return np.where((u >= 0) & (u <= 3), (1-np.cos(2*np.pi*u/3))/6, 0)

def make_rom():
    # h=H/16, H in {4,5}. Each count is 1/2**PHASE_BITS of a turn.
    ideal = MODULUS/16 * np.diff(q(np.arange(3*SPS+1)/SPS))
    table = np.rint(ideal).astype(np.int64)
    # Preserve symmetry and exact total area so completed pulses do not drift.
    correction = MODULUS//32 - int(table.sum())
    assert correction % 2 == 0
    table[len(table)//2-1:len(table)//2+1] += correction//2
    assert np.array_equal(table, table[::-1])
    assert table.sum() == MODULUS//32
    assert table.min() >= 0 and table.max() < 65536
    return table

ROM = make_rom()

class Core:
    """One call = one fabric clock edge; one accepted step = one waveform sample.

    Input dibit is an integer 0..3 with the first bit as MSB. sample_ce can
    freeze the model. Missing dibits at m=0 also freeze waveform time.
    """
    def __init__(self):
        self.reset()

    def reset(self):
        self.m = 0
        self.weights = [0, 0, 0]
        self.next_H = 4
        self.phase = 0

    @property
    def ready(self):
        return self.m == 0

    def tick(self, dibit=0, valid=False, sample_ce=True, reset=False):
        if reset:
            self.reset()
            return None
        if not sample_ce or (self.ready and not valid):
            return None
        if self.ready:
            if dibit not in range(4):
                raise ValueError('dibit must be 0..3')
            symbol = 2*int(dibit)-3
            self.weights = [symbol*self.next_H, *self.weights[:2]]
            self.next_H = 9-self.next_H
        branches = [self.weights[j]*int(ROM[j*SPS+self.m]) for j in range(3)]
        increment = sum(branches)
        result = {'m': self.m, 'weights': self.weights.copy(), 'branches': branches,
                  'increment': increment, 'phase': self.phase}
        self.phase = (self.phase+increment) % MODULUS
        self.m = (self.m+1) % SPS
        return result

def run(dibits):
    core = Core()
    trace = []
    for dibit in dibits:
        for _ in range(SPS):
            trace.append(core.tick(int(dibit), valid=True))
    return trace

def reference(dibits):
    """Floating-point convolution, independent of the clocked shift-register loop."""
    symbols = 2*np.asarray(dibits, dtype=int)-3
    h = np.resize([4/16, 5/16], len(symbols))
    impulses = np.zeros(len(symbols)*SPS)
    impulses[::SPS] = symbols*h
    dq = np.diff(q(np.arange(3*SPS+1)/SPS))
    phase_turns = np.r_[0., np.cumsum(np.convolve(impulses, dq))]
    frequency = np.convolve(impulses, g(np.arange(3*SPS+1)/SPS))
    n = len(impulses)
    return phase_turns[:n], frequency[:n]

def export(directory='hardware'):
    root = Path(directory)
    root.mkdir(exist_ok=True)
    entries = ',\n'.join(f'    {i} => {int(v)}' for i, v in enumerate(ROM))
    package = f'''library ieee;
use ieee.std_logic_1164.all;
package cpm_rom_pkg is
  constant SPS : positive := {SPS};
  constant PHASE_BITS : positive := {PHASE_BITS};
  type rom_t is array (0 to 3*SPS-1) of integer range 0 to 65535;
  constant AREA_ROM : rom_t := (\n{entries}\n  );
end package;
'''
    (root/'cpm_rom_pkg.vhd').write_text(package, encoding='utf-8')
    # Reproducible clock vectors include reset, CE gaps, input starvation,
    # repeated dibits, both index parities, and a mid-symbol reset.
    rng = np.random.default_rng(106)
    core = Core()
    lines = []
    for cycle in range(6000):
        rst = int(cycle in (0, 1777, 4003))
        ce = int(rng.random() > .18)
        valid = int(rng.random() > .3)
        dibit = 0 if cycle < 350 else int(rng.integers(4))
        ready = int(core.ready)
        result = core.tick(dibit, bool(valid), bool(ce), bool(rst))
        out_valid = int(result is not None)
        inc = result['increment'] if result else 0
        phase = result['phase'] if result else 0
        lines.append(f'{rst} {ce} {valid} {dibit} {ready} {out_valid} {inc} {phase}')
    (root/'vectors.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    return root

if __name__ == '__main__':
    print(f'Exported ROM and clock vectors to {export()}')
