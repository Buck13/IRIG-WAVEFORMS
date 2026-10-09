"""Verify matching Vivado exports and record hashes after timing-gated export."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parent / 'artifacts' / 'pcm-fm'
timing = (root / 'timing.rpt').read_text()
if 'All user specified timing constraints are met.' not in timing or 'VIOLATED' in timing:
    raise SystemExit('Timing report does not pass')
bit = (root / 'pluto_pcm_fm.bit').read_bytes()
raw = (root / 'pluto_pcm_fm.bin').read_bytes()
if not raw or not bit.endswith(raw):
    raise SystemExit('Standalone BIT/BIN payload mismatch')
with ZipFile(root / 'pluto_pcm_fm.xsa') as archive:
    names = [name for name in archive.namelist() if name.endswith('.bit')]
    if len(names) != 1 or not archive.read(names[0]).endswith(raw):
        raise SystemExit('XSA bitstream payload mismatch')
manager = (root / 'pluto_pcm_fm.bit.bin').read_bytes()
swapped = b''.join(raw[i:i+4][::-1] for i in range(0, len(raw), 4))
if manager != swapped + bytes.fromhex('00000020'):
    raise SystemExit('Unexpected Bootgen conversion: expected swapped words plus padding NOP')
manifest = {
    path.name: {'bytes': path.stat().st_size,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    for path in sorted(root.iterdir())
    if path.is_file() and path.name != 'sha256.json'
}
(root / 'sha256.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('PASS: timing, BIT/BIN/XSA payloads and Bootgen conversion; SHA-256 manifest saved')
