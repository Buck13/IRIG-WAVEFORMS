"""Load volatile PCM-FM image, install controls and prepare muted loopback settings."""
from pathlib import Path
import argparse,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
PUTTY=Path('C:/Program Files (x86)/PuTTY')
DEFAULT_KEY='SHA256:l4u2JjiFnD8v5kQAu/mgotcspemMDj5P/qE2HIlZMNY'
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--host',default='192.168.2.1');p.add_argument('--host-key',default=DEFAULT_KEY)
 p.add_argument('--password',default='analog');a=p.parse_args()
 opts=['-batch','-hostkey',a.host_key,'-pw',a.password]
 def ssh(cmd):
  r=subprocess.run([str(PUTTY/'plink.exe'),'-ssh',*opts,'root@'+a.host,cmd],capture_output=True,text=True,timeout=12)
  if r.returncode:raise RuntimeError(r.stderr.strip() or r.stdout.strip())
  return r.stdout
 # Verify identity before transfer; never accept a changed key automatically.
 print(ssh('cat /sys/class/fpga_manager/fpga0/state'))
 for source,target in [(ROOT/'plutoplus-vivado2026/artifacts/pcm-fm/pluto_pcm_fm.bit.bin','/lib/firmware/pluto_pcm_fm.bit.bin'),(ROOT/'load-pcm-fm-temporary.sh','/tmp/load-pcm-fm-temporary.sh'),(ROOT/'live/pcm-fm-control.sh','/tmp/pcm-fm-control.sh')]:
  subprocess.run([str(PUTTY/'pscp.exe'),'-scp',*opts,str(source),'root@'+a.host+':'+target],check=True,timeout=30)
 print('Reloading FPGA in RAM. USB temporarily disconnects. TX remains muted.')
 ssh('nohup setsid sh /tmp/load-pcm-fm-temporary.sh --confirmed-attenuated-loopback </dev/null >/tmp/pcm-fm-load.log 2>&1 &')
 deadline=time.monotonic()+60
 while time.monotonic()<deadline:
  time.sleep(2)
  try:log=ssh('cat /tmp/pcm-fm-load.log')
  except (RuntimeError,subprocess.TimeoutExpired):continue
  if 'RELOAD_FAILED' in log:raise RuntimeError(log)
  if 'TEMPORARY_LOAD_DONE' in log:break
 else:raise RuntimeError('Reload not confirmed; inspect /tmp/pcm-fm-load.log over serial. Do not enable TX.')
 print(ssh('sh /tmp/pcm-fm-control.sh prepare'))
 print(ssh('sh /tmp/pcm-fm-control.sh status'))
 print('Ready. Start the RX viewer, then enable TX yourself through SSH.')
if __name__=='__main__':main()
