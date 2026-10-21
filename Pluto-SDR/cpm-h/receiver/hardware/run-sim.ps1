$ErrorActionPreference = 'Stop'
$ghdl = Join-Path $PSScriptRoot '..\..\..\..\CPM-H\.tools\ghdl\bin\ghdl.exe'
Push-Location $PSScriptRoot
try {
  & $ghdl -a --std=08 cpm_branch_metric.vhd tb_cpm_branch_metric.vhd
  if ($LASTEXITCODE) { throw 'GHDL analysis failed' }
  & $ghdl -e --std=08 tb_cpm_branch_metric
  if ($LASTEXITCODE) { throw 'GHDL elaboration failed' }
  & $ghdl -r --std=08 tb_cpm_branch_metric --assert-level=error
  if ($LASTEXITCODE) { throw 'GHDL simulation failed' }
} finally { Pop-Location }
