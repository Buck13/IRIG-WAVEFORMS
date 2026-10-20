param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin', [switch]$BuildOnly)
$ErrorActionPreference='Stop'
$logs="$PSScriptRoot/logs"
New-Item -ItemType Directory -Force $logs | Out-Null
& 'C:\SDR_Work\IRIG-WAVEFORMS\.venv\Scripts\python.exe' "$PSScriptRoot/../cpm-h/generate_nco.py"
if ($LASTEXITCODE -ne 0) { throw 'CPM-H NCO generation failed' }
if (-not $BuildOnly) {
  & "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/integrate-cpm-h-postfir.tcl".Replace('\','/')) -log "$logs/cpm-h-postfir-integration.log" -journal "$logs/cpm-h-postfir-integration.jou"
  if ($LASTEXITCODE -ne 0) { throw 'CPM-H integration failed' }
}
& "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/build-cpm-h-postfir.tcl".Replace('\','/')) -log "$logs/cpm-h-postfir-build.log" -journal "$logs/cpm-h-postfir-build.jou"
if ($LASTEXITCODE -ne 0) { throw 'CPM-H build or timing check failed' }
if (-not (Select-String -Path "$logs/cpm-h-postfir-build.log" -SimpleMatch 'CPM_H_BUILD_TIMING_CHECKED_AND_EXPORTED' -Quiet)) { throw 'No validated CPM-H export marker' }
Push-Location "$PSScriptRoot/artifacts/cpm-h-postfir"
try {
  Set-Content -Encoding ascii fpga-manager.bif 'all: { pluto_cpm_h.bit }'
  & "$VivadoBin/bootgen.bat" -arch zynq -image fpga-manager.bif -process_bitstream bin -w on
  if ($LASTEXITCODE -ne 0) { throw 'CPM-H Bootgen conversion failed' }
} finally { Pop-Location }
Write-Host 'PASS: separate CPM-H Pluto image built, timed, checked and converted for FPGA Manager'
