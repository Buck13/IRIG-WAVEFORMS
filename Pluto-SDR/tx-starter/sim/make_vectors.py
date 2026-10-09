"""Independent bit-recurrence reference, not the RTL shift-register update."""
from pathlib import Path

def sequence(seed):
    bits = [(seed >> i) & 1 for i in range(15)]
    for n in range(32767):
        bits.append(bits[n + 14] ^ bits[n])
    # All nonzero 15-bit windows exactly once, and the initial window repeats.
    windows = {tuple(bits[n:n+15]) for n in range(32767)}
    assert len(windows) == 32767
    assert (0,) * 15 not in windows
    assert bits[32767:32782] == bits[:15]
    assert sum(bits[:32767]) == 16384
    return bits[:32767]

for name, seed in [('default', 0x7fff), ('alternate', 0x1234)]:
    bits = sequence(seed)
    Path(f'pn15_{name}.mem').write_text(''.join(f'{b:x}\n' for b in bits))
print('PASS: independent PN15 reference: 32767 distinct nonzero states, both seeds')
