param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$build="$PSScriptRoot/build/target-synth"
New-Item -ItemType Directory -Force $build | Out-Null
& 'C:\SDR_Work\IRIG-WAVEFORMS\.venv\Scripts\python.exe' "$PSScriptRoot/generate_nco.py"
if ($LASTEXITCODE -ne 0) { throw 'NCO generation failed' }
& "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/synth-target.tcl".Replace('\','/')) -log "$build/vivado.log" -journal "$build/vivado.jou"
if ($LASTEXITCODE -ne 0) { throw 'Target synthesis failed' }
if (-not (Select-String -Path "$build/vivado.log" -SimpleMatch 'CPM_H_TARGET_SYNTHESIS_COMPLETE' -Quiet)) { throw 'Target synthesis marker missing' }
Write-Host 'PASS: CPM-H phase plus I/Q target synthesized; see results/'
