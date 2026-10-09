param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path "$PSScriptRoot/../..").Path
& "$workspace/.venv/Scripts/python.exe" "$PSScriptRoot/sim/generate.py"
if ($LASTEXITCODE -ne 0) { throw 'Vector generation failed' }
Push-Location "$PSScriptRoot/build/xsim"
try {
 & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/hdl/pcm_fm_tables.vhd" "$PSScriptRoot/hdl/pcm_fm_core.vhd" "$PSScriptRoot/sim/pcm_fm_tb.vhd"
 if ($LASTEXITCODE -ne 0) { throw 'VHDL compile failed' }
 & "$VivadoBin/xelab.bat" pcm_fm_tb -s pcm_fm_sim -debug typical
 if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
 & "$VivadoBin/xsim.bat" pcm_fm_sim -tclbatch (("$PSScriptRoot/sim/run.tcl").Replace('\','/')) -wdb pcm_fm.wdb -log pcm_fm.log
 if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
 if (-not (Select-String -Path pcm_fm.log -SimpleMatch 'PASS: PCM FM exact' -Quiet)) { throw 'No simulation PASS marker' }
} finally { Pop-Location }
