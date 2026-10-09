#!/bin/sh
# Device-side controller. start persists after SSH disconnect; stop is explicit.
set -eu
pidfile=/tmp/pcm-fm-tx.pid
log=/tmp/pcm-fm-tx.log
phy=/sys/bus/iio/devices/iio:device0
fw=/lib/firmware/pluto_pcm_fm.bit.bin
hash=7d4c06da4e1387f05e5d982299e4db2ff012f35cabd4c784a9aedfcd089a6fbd
custom() {
 test -f /tmp/pcm-fm-load.log && grep -q TEMPORARY_LOAD_DONE /tmp/pcm-fm-load.log || { echo 'Load verified PCM-FM image first.' >&2; exit 1; }
 printf '%s  %s\n' "$hash" "$fw" | sha256sum -c - >/dev/null
 test "$(cat /sys/class/fpga_manager/fpga0/state)" = operating
}
find_tx() {
 tx=''
 for f in /sys/bus/iio/devices/iio:device*/name; do
  if [ "$(cat "$f")" = cf-ad9361-dds-core-lpc ]; then tx=${f%/name}; fi
 done
 test -n "$tx"
}
mute() { for f in "$phy"/out_voltage*_hardwaregain; do echo -89.75 > "$f"; done; }
stop_tx() {
 mute
 if [ -f /tmp/pcm-fm-load.log ] && grep -q TEMPORARY_LOAD_DONE /tmp/pcm-fm-load.log; then devmem 0x41210000 32 0; fi
 if [ -f "$pidfile" ]; then
  pid=$(cat "$pidfile")
  case "$pid" in ''|*[!0-9]*) echo 'Invalid PID file' >&2; exit 1;; esac
  if [ -r /proc/"$pid"/cmdline ] && tr '\000' ' ' </proc/"$pid"/cmdline | grep -q '^iio_writedev .*cf-ad9361-dds-core-lpc'; then kill -TERM "$pid"; fi
  rm -f "$pidfile"
 fi
 echo 'TX muted; FPGA source deselected; owned stream stopped.'
}
find_tx
test "$(cat "$phy/name")" = ad9361-phy
case "${1:-status}" in
 prepare)
  custom
  for f in /sys/bus/iio/devices/iio:device*/buffer/enable; do test "$(cat "$f")" = 0 || { echo 'Stop RX viewer and all streams before prepare.' >&2; exit 1; }; done
  mute; devmem 0x41210000 32 0
  echo fdd > "$phy/ensm_mode"
  echo 2500000 > "$phy/out_voltage_sampling_frequency"
  echo 2500000 > "$phy/in_voltage_sampling_frequency"
  echo 1000000 > "$phy/out_voltage_rf_bandwidth"
  echo 1000000 > "$phy/in_voltage_rf_bandwidth"
  echo 915000000 > "$phy/out_altvoltage0_RX_LO_frequency"
  echo 915000000 > "$phy/out_altvoltage1_TX_LO_frequency"
  for ch in 0 1; do echo manual > "$phy/in_voltage${ch}_gain_control_mode"; echo 30 > "$phy/in_voltage${ch}_hardwaregain"; done
  for f in "$tx"/out_altvoltage*_raw; do echo 0 > "$f"; done
  echo 'Prepared 915 MHz / 2.5 MS/s; TX remains muted. Start RX viewer next.'
  ;;
 start)
  custom
  test "${2:-}" = --attenuated-loopback || { echo 'Use start --attenuated-loopback for TX1 -> 30 dB -> RX2.' >&2; exit 1; }
  test "$(cat "$tx/buffer/enable")" = 0 || { echo 'TX buffer already active; stop its owner first.' >&2; exit 1; }
  test "$(cat "$phy/out_voltage_sampling_frequency")" = 2500000 || { echo 'Run prepare first.' >&2; exit 1; }
  test "$(cat "$phy/out_altvoltage1_TX_LO_frequency")" = 915000000 || { echo 'Run prepare first.' >&2; exit 1; }
  mute; devmem 0x41210000 32 0
  trap 'stop_tx' 0
  dd if=/dev/zero of=/tmp/pcm-fm-zero.iq bs=32768 count=1 2>/dev/null
  nohup iio_writedev -c -b 4096 cf-ad9361-dds-core-lpc voltage0 voltage1 voltage2 voltage3 </tmp/pcm-fm-zero.iq >"$log" 2>&1 &
  echo $! > "$pidfile"
  sleep 1
  kill -0 "$(cat "$pidfile")"
  test "$(cat "$tx/buffer/enable")" = 1
  devmem 0x41210000 32 1
  echo -40 > "$phy/out_voltage0_hardwaregain"
  trap - 0
  echo 'Continuous FPGA PN15 PCM-FM TX ON. Persists after SSH closes. Run: sh /tmp/pcm-fm-control.sh stop'
  ;;
 stop) stop_tx ;;
 status)
  cat /sys/class/fpga_manager/fpga0/state
  if [ -f /tmp/pcm-fm-load.log ] && grep -q TEMPORARY_LOAD_DONE /tmp/pcm-fm-load.log; then echo "source=$(devmem 0x41210000 32)"; else echo 'No verified PCM-FM load this boot.'; fi
  echo "TX buffer=$(cat "$tx/buffer/enable")"
  for f in "$phy"/out_voltage*_hardwaregain; do echo "$f: $(cat "$f")"; done
  ;;
 *) echo 'Usage: sh pcm-fm-control.sh prepare|start --attenuated-loopback|stop|status'; exit 2;;
esac
