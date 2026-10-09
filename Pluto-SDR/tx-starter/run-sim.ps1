param([string]$VivadoBin = 'C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path "$PSScriptRoot/../..").Path
$python = "$workspace/.venv/Scripts/python.exe"
$outputDir = "$PSScriptRoot/build/sim"
New-Item -ItemType Directory -Force $outputDir | Out-Null
Push-Location $outputDir
try {
    & $python "$PSScriptRoot/sim/make_vectors.py"
    if ($LASTEXITCODE -ne 0) { throw 'Reference checks failed' }
    & "$VivadoBin/xvlog.bat" --sv "$PSScriptRoot/rtl/bpsk_mapper.sv" "$PSScriptRoot/rtl/pn15_bpsk_tx.sv" "$PSScriptRoot/sim/pn15_bpsk_tx_tb.sv"
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    foreach ($sps in @(1, 8)) {
        & "$VivadoBin/xelab.bat" "pn15_bpsk_tx_tb_sps$sps" -s "pn15_tx_$sps"
        if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
        & "$VivadoBin/xsim.bat" "pn15_tx_$sps" -runall -log "xsim-sps$sps.log"
        if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
        if (-not (Select-String -Path "xsim-sps$sps.log" -SimpleMatch "PASS: PN15 BPSK TX, SPS=$sps," -Quiet)) { throw 'Simulation did not pass' }
    }
} finally { Pop-Location }
