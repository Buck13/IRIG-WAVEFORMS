param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$build="$PSScriptRoot/build/target-xsim"
New-Item -ItemType Directory -Force $build | Out-Null
Copy-Item -Force "$PSScriptRoot/reference/hardware/vectors.txt" "$build/vectors.txt"
& 'C:\SDR_Work\IRIG-WAVEFORMS\.venv\Scripts\python.exe' "$PSScriptRoot/generate_nco.py"
if ($LASTEXITCODE -ne 0) { throw 'NCO generation failed' }
Push-Location $build
try {
  & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/hdl/cpm_rom_pkg.vhd" "$PSScriptRoot/hdl/cpm_h_nco_pkg.vhd" "$PSScriptRoot/reference/hardware/cpm_core.vhd" "$PSScriptRoot/hdl/cpm_h_phase_core.vhd" "$PSScriptRoot/hdl/cpm_h_iq_rom.vhd" "$PSScriptRoot/hdl/cpm_h_tx_core.vhd" "$PSScriptRoot/hdl/pluto_cpm_h_adapter.vhd" "$PSScriptRoot/hdl/pluto_cpm_h_top.vhd" "$PSScriptRoot/sim/tb_cpm_h_target.vhd"
  if ($LASTEXITCODE -ne 0) { throw 'Target VHDL compile failed' }
  & "$VivadoBin/xelab.bat" tb_cpm_h_target -s cpm_h_target_sim -debug typical
  if ($LASTEXITCODE -ne 0) { throw 'Target VHDL elaboration failed' }
  & "$VivadoBin/xsim.bat" cpm_h_target_sim -tclbatch ("$PSScriptRoot/sim/run-target.tcl".Replace('\','/')) -log target-xsim.log
  if ($LASTEXITCODE -ne 0) { throw 'Target XSIM failed' }
  if (-not (Select-String -Path target-xsim.log -SimpleMatch 'PASS: target phase and IQ equal reference' -Quiet)) { throw 'Target PASS marker missing' }
} finally { Pop-Location }
Write-Host 'PASS: pipelined CPM-H phase and I/Q match the imported reference'
