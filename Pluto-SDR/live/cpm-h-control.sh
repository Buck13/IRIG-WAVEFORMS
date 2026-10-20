#!/bin/sh
# Device-side controller. start persists after SSH disconnect; stop is explicit.
set -eu
pidfile=/tmp/cpm-h-tx.pid
log=/tmp/cpm-h-tx.log
phy=/sys/bus/iio/devices/iio:device0
fw=/lib/firmware/pluto_cpm_h.bit.bin
hash=253ba93d4bc32076c68fa717e237fe3cfe1b5f0deb8b7af012b3462a7aae1e62
custom() {
 test -f /tmp/cpm-h-load.log && grep -q TEMPORARY_LOAD_DONE /tmp/cpm-h-load.log || { echo 'Load verified CPM-H image first.' >&2; exit 1; }
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
mute() {
 echo fdd > "$phy/ensm_mode"
 printf '%s' -89.750000 > "$phy/out_voltage0_hardwaregain" 2>/dev/null || :
 case "$(cat "$phy/out_voltage0_hardwaregain")" in -89.750000*) ;; *) echo 'Could not verify TX1 mute.' >&2; return 1;; esac
}
stop_tx() {
 mute
 if [ -f /tmp/cpm-h-load.log ] && grep -q TEMPORARY_LOAD_DONE /tmp/cpm-h-load.log; then devmem 0x41210000 32 0; fi
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
  dd if=/dev/zero of=/tmp/cpm-h-zero.iq bs=32768 count=1 2>/dev/null
  nohup iio_writedev -c -b 4096 cf-ad9361-dds-core-lpc voltage0 voltage1 voltage2 voltage3 </tmp/cpm-h-zero.iq >"$log" 2>&1 &
  echo $! > "$pidfile"
  sleep 1
  kill -0 "$(cat "$pidfile")"
  test "$(cat "$tx/buffer/enable")" = 1
  devmem 0x41210000 32 1
  echo -40 > "$phy/out_voltage0_hardwaregain"
  trap - 0
  echo 'Continuous FPGA PN15 CPM-H TX ON. Persists after SSH closes. Run: sh /tmp/cpm-h-control.sh stop'
  ;;
 stop) stop_tx ;;
 status)
  cat /sys/class/fpga_manager/fpga0/state
  if [ -f /tmp/cpm-h-load.log ] && grep -q TEMPORARY_LOAD_DONE /tmp/cpm-h-load.log; then echo "source=$(devmem 0x41210000 32)"; else echo 'No verified CPM-H load this boot.'; fi
  echo "TX buffer=$(cat "$tx/buffer/enable")"
  for f in "$phy"/out_voltage*_hardwaregain; do echo "$f: $(cat "$f")"; done
  ;;
 *) echo 'Usage: sh cpm-h-control.sh prepare|start --attenuated-loopback|stop|status'; exit 2;;
esac
