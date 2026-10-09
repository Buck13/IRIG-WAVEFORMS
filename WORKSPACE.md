# Local workspace and relocation

Canonical working checkout: `C:\SDR_Work\IRIG-WAVEFORMS`.
GitHub origin: https://github.com/Buck13/IRIG-WAVEFORMS

The former OneDrive CPM-H directory included a nested `.publish/IRIG-WAVEFORMS`
checkout. This repository starts from that GitHub history and includes the local
CPM-H additions. Pluto-SDR was imported as a Git subtree without squashing,
preserving all of its commits. Large ignored files are copied locally, not
added to Git. Original locations are retained as backups, not deleted.

## Environment

Select `C:\SDR_Work\IRIG-WAVEFORMS\.venv\Scripts\python.exe` for both projects.
Recreate it with Python 3.12:

```powershell
cd C:\SDR_Work\IRIG-WAVEFORMS
py -3.12 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install -r CPM-H\requirements.txt -r Pluto-SDR\pcm-fm\requirements.txt
```

Notebook frontends should select that interpreter. No reliance on a Codex
Python environment remains in the relocated simulation/build launchers.
The CPM-H GHDL tool folder, Pluto libiio executables, captures, artifact files,
vendor HDL, and generated Vivado builds are copied locally. Environment/cache
folders were recreated or omitted rather than blindly moving old virtualenvs.
Vivado 2026.1 and PuTTY still use their installed machine locations.

## Tested hardware workflow

With the verified PCM-FM image still loaded and the attenuated loopback connected:

```powershell
cd C:\SDR_Work\IRIG-WAVEFORMS
& .\.venv\Scripts\python.exe .\Pluto-SDR\test-pcm-fm-hardware.py
```

That command transmits briefly, captures and mutes TX. It does not load the
bitstream. A power cycle requires a fresh temporary load first. See
`Pluto-SDR/pcm-fm/INTEGRATION-RESULT.md` and the loader script.
Relocation did not run a new transmission or change the Pluto.

Offline analysis:

```powershell
& .\.venv\Scripts\python.exe .\Pluto-SDR\analyze-pcm-fm-hardware.py .\Pluto-SDR\captures\pcm-fm-hardware-20261009-072118
```

Vivado project:
`Pluto-SDR/plutoplus-vivado2026/build/pcm-fm/pluto_pcm_fm.xpr`.
Copied project configuration paths were rebased. Historical reports, payloads
and manifests remain byte-identical evidence from the original build. Rebuild
scripts now resolve the new source location. Bitstream hashes were checked.

## Backup locations

- `C:\Users\hendr\OneDrive\Documents\ChatGPT\CPM-H`
- `C:\Users\hendr\.codex\.chatgpt-projects\g-p-6ab23f1236348191a7d8295902dcddaa\pluto-dev`

Do not run both copies as competing working trees. They are retained for recovery;
no deletion or GitHub push was part of the relocation.

Validation completed: relocated PCM-FM Vivado project opened with zero missing
source files and zero old Codex source references. Original missing ghdl/library
IP-repository warning remains; the actual hdl/library repository resolves.
Both BPSK/PCM-FM artifact hashes match, pip check passes, and offline PCM-FM
reanalysis reproduces 126975 bits with zero mismatches. No radio commands ran.
