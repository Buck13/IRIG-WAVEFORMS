param([string]$VivadoBin = 'C:\AMDDesignTools\2026.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$PSScriptRoot/build/vhdl-sim/pn15_default.mem")) {
    throw 'Run run-vhdl-sim.ps1 first to generate and verify the test vectors'
}
New-Item -ItemType Directory -Force "$PSScriptRoot/build" | Out-Null
Push-Location "$PSScriptRoot/build"
try {
    & "$VivadoBin/vivado.bat" -mode batch -source "$PSScriptRoot/create-vivado-project.tcl" -notrace -nojournal -log create-project.log
    if ($LASTEXITCODE -ne 0) { throw 'Project creation or core synthesis failed' }
} finally { Pop-Location }
