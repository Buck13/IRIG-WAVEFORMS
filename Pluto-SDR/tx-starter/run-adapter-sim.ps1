param([string]$VivadoBin = 'C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path "$PSScriptRoot/../..").Path
$outputDir = "$PSScriptRoot/build/adapter-sim"
New-Item -ItemType Directory -Force $outputDir | Out-Null
Push-Location $outputDir
try {
    & "$workspace/rfnoc-dev/.venv/Scripts/python.exe" "$PSScriptRoot/sim/make_vectors.py"
    if ($LASTEXITCODE -ne 0) { throw 'Reference checks failed' }
    & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/vhdl/bpsk_mapper.vhd" "$PSScriptRoot/vhdl/pn15_generator.vhd" "$PSScriptRoot/vhdl/pn15_bpsk_tx.vhd" "$PSScriptRoot/vhdl/pluto_pn15_tx_adapter.vhd" "$PSScriptRoot/sim/pluto_adapter_tb.vhd"
    if ($LASTEXITCODE -ne 0) { throw 'Adapter compilation failed' }
    & "$VivadoBin/xelab.bat" pluto_adapter_tb -s pluto_adapter_sim
    if ($LASTEXITCODE -ne 0) { throw 'Adapter elaboration failed' }
    & "$VivadoBin/xsim.bat" pluto_adapter_sim -runall -log adapter.log
    if ($LASTEXITCODE -ne 0) { throw 'Adapter simulation failed' }
    if (-not (Select-String -Path adapter.log -SimpleMatch 'PASS: PLUTO ADAPTER' -Quiet)) { throw 'Adapter tests did not pass' }
    & "$VivadoBin/xvhdl.bat" --2008 "$PSScriptRoot/vhdl/pluto_pn15_tx_top.vhd" "$PSScriptRoot/sim/pluto_tx_top_tb.vhd"
    if ($LASTEXITCODE -ne 0) { throw 'TX wrapper compilation failed' }
    & "$VivadoBin/xelab.bat" pluto_tx_top_tb -s pluto_tx_top_sim
    if ($LASTEXITCODE -ne 0) { throw 'TX wrapper elaboration failed' }
    & "$VivadoBin/xsim.bat" pluto_tx_top_sim -runall -log tx-top.log
    if ($LASTEXITCODE -ne 0) { throw 'TX wrapper simulation failed' }
    if (-not (Select-String -Path tx-top.log -SimpleMatch 'PASS: PLUTO TX TOP' -Quiet)) { throw 'TX wrapper tests did not pass' }
} finally { Pop-Location }
