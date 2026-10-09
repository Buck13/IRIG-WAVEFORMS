param([string]$VivadoBin='C:\AMDDesignTools\2026.1\Vivado\bin')
$folder=(Resolve-Path "$PSScriptRoot/build/xsim").Path
$script=("$PSScriptRoot/sim/view.tcl").Replace('\','/')
# Visible GUI is intentional: this launcher displays saved simulation signals.
Start-Process "$VivadoBin/xsim.bat" -WorkingDirectory $folder -ArgumentList @('pcm_fm.wdb','-gui','-tclbatch',$script)
