$ErrorActionPreference = 'Stop'
$ghdl = Join-Path $PSScriptRoot '..\..\..\..\CPM-H\.tools\ghdl\bin\ghdl.exe'
Push-Location $PSScriptRoot
try {
  & $ghdl -a --std=08 cpm_branch_metric.vhd tb_cpm_branch_metric.vhd cpm_complex_correlator.vhd tb_cpm_complex_correlator.vhd
  if ($LASTEXITCODE) { throw 'GHDL analysis failed' }
  & $ghdl -e --std=08 tb_cpm_branch_metric
  if ($LASTEXITCODE) { throw 'GHDL branch-metric elaboration failed' }
  & $ghdl -r --std=08 tb_cpm_branch_metric --assert-level=error
  if ($LASTEXITCODE) { throw 'GHDL branch-metric simulation failed' }
  & $ghdl -e --std=08 tb_cpm_complex_correlator
  if ($LASTEXITCODE) { throw 'GHDL correlator elaboration failed' }
  & $ghdl -r --std=08 tb_cpm_complex_correlator --assert-level=error
  if ($LASTEXITCODE) { throw 'GHDL correlator simulation failed' }
} finally { Pop-Location }
