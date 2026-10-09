param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path "$PSScriptRoot/../..").Path
& "$workspace/.venv/Scripts/python.exe" "$PSScriptRoot/sim/generate.py"
if ($LASTEXITCODE -ne 0) { throw 'Vectors failed' }
Push-Location "$PSScriptRoot/build/xsim"
try {
 $files=@('hdl/pcm_fm_tables.vhd','hdl/pcm_fm_core.vhd','hdl/pluto_pcm_fm_adapter.vhd','hdl/pluto_pcm_fm_top.vhd','sim/pcm_adapter_tb.vhd') | ForEach-Object { "$PSScriptRoot/$_" }
 & "$VivadoBin/xvhdl.bat" --2008 @files
 if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
 & "$VivadoBin/xelab.bat" pcm_adapter_tb -s pcm_adapter_sim -debug typical
 if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
 & "$VivadoBin/xsim.bat" pcm_adapter_sim -tclbatch (("$PSScriptRoot/sim/adapter-run.tcl").Replace('\','/')) -wdb pcm_adapter.wdb -log pcm_adapter.log
 if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
 if (-not (Select-String -Path pcm_adapter.log -SimpleMatch 'PASS: PCM ADAPTER' -Quiet)) { throw 'No PASS marker' }
} finally { Pop-Location }
