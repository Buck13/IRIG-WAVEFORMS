param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force "$PSScriptRoot/build" | Out-Null
$script=("$PSScriptRoot/synth-standalone.tcl").Replace('\','/')
& "$VivadoBin/vivado.bat" -mode batch -source $script -log "$PSScriptRoot/build/standalone-vivado.log" -journal "$PSScriptRoot/build/standalone-vivado.jou"
if ($LASTEXITCODE -ne 0) { throw 'Standalone implementation failed' }
if (-not (Select-String -Path "$PSScriptRoot/build/standalone-vivado.log" -SimpleMatch 'PCM_FM_STANDALONE_COMPLETE' -Quiet)) { throw 'Missing completion marker' }
