param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$build="$PSScriptRoot/build/reference-xsim"
New-Item -ItemType Directory -Force $build | Out-Null
Copy-Item -Force "$PSScriptRoot/reference/hardware/vectors.txt" "$build/vectors.txt"
Push-Location $build
try {
  & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/reference/hardware/cpm_rom_pkg.vhd" "$PSScriptRoot/reference/hardware/cpm_core.vhd" "$PSScriptRoot/reference/hardware/tb_cpm_core.vhd"
  if ($LASTEXITCODE -ne 0) { throw 'Reference VHDL compile failed' }
  & "$VivadoBin/xelab.bat" tb_cpm_core -s cpm_reference_sim -debug typical
  if ($LASTEXITCODE -ne 0) { throw 'Reference VHDL elaboration failed' }
  & "$VivadoBin/xsim.bat" cpm_reference_sim -tclbatch ("$PSScriptRoot/sim/run-reference.tcl".Replace('\','/')) -log reference-xsim.log
  if ($LASTEXITCODE -ne 0) { throw 'Reference XSIM failed' }
  if (-not (Select-String -Path reference-xsim.log -SimpleMatch 'PASS: 6000 clock vectors' -Quiet)) { throw 'Reference PASS marker missing' }
} finally { Pop-Location }
Write-Host 'PASS: imported CPM-H reference matched all 6000 vectors in XSIM'
