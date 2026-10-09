param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin', [switch]$BuildOnly)
$ErrorActionPreference='Stop'
$logs="$PSScriptRoot/logs"
New-Item -ItemType Directory -Force $logs | Out-Null
if (-not $BuildOnly) {
 & "$VivadoBin/vivado.bat" -mode batch -source (("$PSScriptRoot/integrate-pcm-fm.tcl").Replace('\','/')) -log "$logs/pcm-fm-integration.log" -journal "$logs/pcm-fm-integration.jou"
 if ($LASTEXITCODE -ne 0) { throw 'PCM-FM integration failed' }
}
& "$VivadoBin/vivado.bat" -mode batch -source (("$PSScriptRoot/build-pcm-fm.tcl").Replace('\','/')) -log "$logs/pcm-fm-build.log" -journal "$logs/pcm-fm-build.jou"
if ($LASTEXITCODE -ne 0) { throw 'PCM-FM build or timing check failed' }
if (-not (Select-String -Path "$logs/pcm-fm-build.log" -SimpleMatch 'PCM_FM_BUILD_TIMING_CHECKED_AND_EXPORTED' -Quiet)) { throw 'No validated export marker' }

Push-Location "$PSScriptRoot/artifacts/pcm-fm"
try {
 Set-Content -Encoding ascii fpga-manager.bif 'all: { pluto_pcm_fm.bit }'
 & "$VivadoBin/bootgen.bat" -arch zynq -image fpga-manager.bif -process_bitstream bin -w on
 if ($LASTEXITCODE -ne 0) { throw 'Bootgen failed' }
} finally { Pop-Location }
$workspace=(Resolve-Path "$PSScriptRoot/../..").Path
& "$workspace/.venv/Scripts/python.exe" "$PSScriptRoot/verify-pcm-fm-artifacts.py"
if ($LASTEXITCODE -ne 0) { throw 'Artifact verification failed' }
