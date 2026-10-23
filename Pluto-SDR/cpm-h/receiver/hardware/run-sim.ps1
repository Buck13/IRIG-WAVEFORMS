$ErrorActionPreference = 'Stop'
$ghdl = Join-Path $PSScriptRoot '..\..\..\..\CPM-H\.tools\ghdl\bin\ghdl.exe'
Push-Location $PSScriptRoot
try {
  & $ghdl -a --std=08 cpm_rx_observation_adapter.vhd tb_cpm_rx_observation_adapter.vhd cpm_template_rom6.vhd cpm_correlation_bank.vhd tb_cpm_correlation_bank.vhd cpm_branch_metric.vhd tb_cpm_branch_metric.vhd cpm_complex_correlator.vhd tb_cpm_complex_correlator.vhd cpm_receiver_pkg.vhd cpm_phase_acs4.vhd tb_cpm_phase_acs4.vhd cpm_schedule_pkg.vhd cpm_state_scheduler.vhd tb_cpm_state_scheduler.vhd cpm_metric_tdp_ram.vhd cpm_metric_banks.vhd tb_cpm_metric_banks.vhd cpm_viterbi_engine.vhd tb_cpm_viterbi_engine.vhd cpm_survivor_traceback.vhd tb_cpm_survivor_traceback.vhd cpm_viterbi_decoder.vhd cpm_h_detector.vhd cpm_rx_manual_frontend.vhd
  if ($LASTEXITCODE) { throw 'GHDL analysis failed' }
  foreach ($test in @('tb_cpm_rx_observation_adapter','tb_cpm_correlation_bank','tb_cpm_branch_metric','tb_cpm_complex_correlator','tb_cpm_phase_acs4','tb_cpm_state_scheduler','tb_cpm_metric_banks','tb_cpm_viterbi_engine','tb_cpm_survivor_traceback')) {
    & $ghdl -e --std=08 $test
    if ($LASTEXITCODE) { throw "$test elaboration failed" }
    & $ghdl -r --std=08 $test --assert-level=error
    if ($LASTEXITCODE) { throw "$test simulation failed" }
  }
} finally { Pop-Location }
