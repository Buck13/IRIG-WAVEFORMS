$ErrorActionPreference = 'Stop'
$ghdl = Join-Path $PSScriptRoot '..\..\..\..\CPM-H\.tools\ghdl\bin\ghdl.exe'
Push-Location $PSScriptRoot
try {
  & $ghdl -a --std=08 cpm_branch_metric.vhd tb_cpm_branch_metric.vhd cpm_complex_correlator.vhd tb_cpm_complex_correlator.vhd cpm_receiver_pkg.vhd cpm_phase_acs4.vhd tb_cpm_phase_acs4.vhd cpm_schedule_pkg.vhd cpm_state_scheduler.vhd tb_cpm_state_scheduler.vhd cpm_metric_tdp_ram.vhd cpm_metric_banks.vhd tb_cpm_metric_banks.vhd cpm_viterbi_engine.vhd tb_cpm_viterbi_engine.vhd
  if ($LASTEXITCODE) { throw 'GHDL analysis failed' }
  foreach ($test in @('tb_cpm_branch_metric','tb_cpm_complex_correlator','tb_cpm_phase_acs4','tb_cpm_state_scheduler','tb_cpm_metric_banks','tb_cpm_viterbi_engine')) {
    & $ghdl -e --std=08 $test
    if ($LASTEXITCODE) { throw "$test elaboration failed" }
    & $ghdl -r --std=08 $test --assert-level=error
    if ($LASTEXITCODE) { throw "$test simulation failed" }
  }
} finally { Pop-Location }
