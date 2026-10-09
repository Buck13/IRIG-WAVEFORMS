param([string]$VivadoBin = 'C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path "$PSScriptRoot/../..").Path
$outputDir = "$PSScriptRoot/build/vhdl-sim"
New-Item -ItemType Directory -Force $outputDir | Out-Null
Push-Location $outputDir
try {
    & "$workspace/.venv/Scripts/python.exe" "$PSScriptRoot/sim/make_vectors.py"
    if ($LASTEXITCODE -ne 0) { throw 'Reference checks failed' }
    & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/vhdl/bpsk_mapper.vhd" "$PSScriptRoot/vhdl/pn15_generator.vhd" "$PSScriptRoot/vhdl/pn15_bpsk_tx.vhd" "$PSScriptRoot/sim/pn15_bpsk_vhdl_tb.vhd"
    if ($LASTEXITCODE -ne 0) { throw 'VHDL compilation failed' }
    & "$VivadoBin/xelab.bat" pn15_bpsk_vhdl_tb -s pn15_vhdl_sim
    if ($LASTEXITCODE -ne 0) { throw 'VHDL elaboration failed' }
    & "$VivadoBin/xsim.bat" pn15_vhdl_sim -runall -log xsim-vhdl.log
    if ($LASTEXITCODE -ne 0) { throw 'VHDL simulation failed' }
    if (-not (Select-String -Path xsim-vhdl.log -SimpleMatch 'PASS: ALL VHDL TX TESTS' -Quiet)) { throw 'VHDL tests did not pass' }
} finally { Pop-Location }
