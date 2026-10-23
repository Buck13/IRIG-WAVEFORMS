param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin', [switch]$BuildOnly)
$ErrorActionPreference='Stop'
$logs="$PSScriptRoot/logs"
New-Item -ItemType Directory -Force $logs | Out-Null
if (-not $BuildOnly) {
  & "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/integrate-cpm-h-rx-manual.tcl".Replace('\','/')) -log "$logs/cpm-h-rx-integration.log" -journal "$logs/cpm-h-rx-integration.jou"
  if ($LASTEXITCODE -ne 0) { throw 'CPM-H receiver integration failed' }
}
& "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/synth-cpm-h-rx-manual.tcl".Replace('\','/')) -log "$logs/cpm-h-rx-synthesis.log" -journal "$logs/cpm-h-rx-synthesis.jou"
if ($LASTEXITCODE -ne 0) { throw 'CPM-H receiver synthesis failed' }
& "$VivadoBin/vivado.bat" -mode batch -source ("$PSScriptRoot/build-cpm-h-rx-manual.tcl".Replace('\','/')) -log "$logs/cpm-h-rx-build.log" -journal "$logs/cpm-h-rx-build.jou"
if ($LASTEXITCODE -ne 0) { throw 'CPM-H receiver implementation or validation failed' }
if (-not (Select-String -Path "$logs/cpm-h-rx-build.log" -SimpleMatch 'CPM_H_RX_MANUAL_TIMING_CHECKED_AND_EXPORTED' -Quiet)) { throw 'No validated CPM-H receiver export marker' }
Push-Location "$PSScriptRoot/artifacts/cpm-h-rx-manual"
try {
  Set-Content -Encoding ascii fpga-manager.bif 'all: { pluto_cpm_h_rx_manual.bit }'
  & "$VivadoBin/bootgen.bat" -arch zynq -image fpga-manager.bif -process_bitstream bin -w on
  if ($LASTEXITCODE -ne 0) { throw 'CPM-H receiver Bootgen conversion failed' }
} finally { Pop-Location }
Write-Host 'PASS: RX-only CPM-H Pluto image built, timed, checked and converted for FPGA Manager'
