# SOQPSK-TG trellis layer

`soqpsk_trellis.py` is the max-log reference decoder. It has four states (the previous two bits), two transitions per state, survivor selection, traceback, and a soft LLR equal to the best zero-branch metric minus the best one-branch metric.

`soqpsk_trellis.vhd` is the corresponding streaming fixed-point metric engine. It emits one hard bit and one signed 8-bit LLR per observation. The branch function is deliberately isolated in `expected_branch`/the `e` assignment so the exact IRIG-106 SOQPSK-TG Laurent branch coefficients can replace the teaching coefficients without changing the trellis plumbing.

Build with Vivado 2026.1:

```powershell
call C:\AMDDesignTools\2026.1\Vivado\settings64.bat
xvhdl --2008 soqpsk_trellis.vhd tb_soqpsk_trellis.vhd
xelab --debug typical tb_soqpsk_trellis -s soqpsk_trellis_sim
xsim soqpsk_trellis_sim -runall
```
