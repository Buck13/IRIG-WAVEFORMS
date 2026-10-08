param(
    [ValidateSet('PackageIp','Baseline')][string]$Stage = 'PackageIp',
    [string]$Vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
)
$ErrorActionPreference = 'Stop'
$scriptName = if ($Stage -eq 'PackageIp') { 'package-ip.tcl' } else { 'build-baseline.tcl' }
$buildDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $buildDir | Out-Null
Push-Location $buildDir
try {
    & $Vivado -mode batch -source (Join-Path $PSScriptRoot $scriptName) -log "$Stage.log" -journal "$Stage.jou"
    if ($LASTEXITCODE -ne 0) { throw "Vivado $Stage failed. See $buildDir\$Stage.log" }
} finally { Pop-Location }
