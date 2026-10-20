param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$build="$PSScriptRoot/build/reference-synth"
New-Item -ItemType Directory -Force $build | Out-Null
& "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/synth-reference.tcl".Replace('\','/')) -log "$build/vivado.log" -journal "$build/vivado.jou"
if ($LASTEXITCODE -ne 0) { throw 'Reference synthesis failed' }
if (-not (Select-String -Path "$build/vivado.log" -SimpleMatch 'CPM_H_REFERENCE_SYNTHESIS_COMPLETE' -Quiet)) { throw 'Synthesis completion marker missing' }
Write-Host 'PASS: imported CPM-H reference synthesized; see results/'
