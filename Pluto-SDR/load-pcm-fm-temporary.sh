#!/bin/sh
# Device-side candidate loader. RAM only; never writes MTD or boot variables.
# PCM-FM adaptation of the tested PN15 loader; RAM-only FPGA update.
set -eu
# Launch with nohup + setsid, stdin detached and output redirected to a RAM log.
. /etc/device_config
gadget=/sys/kernel/config/usb_gadget/composite_gadget
usb_stopped=0
restore_usb() {
    if ! pidof iiod >/dev/null; then
        start-stop-daemon -S -b -q -m -p /var/run/iiod.pid -x /usr/sbin/iiod -- -D -n "$ENDPOINTS" -F /dev/iio_ffs || return 1
        sleep 1
    fi
    if [ -z "$(cat "$gadget/UDC")" ]; then printf 'ci_hdrc.0\n' > "$gadget/UDC"; fi
}
finish() {
    rc=$?
    trap - 0
    if [ "$usb_stopped" = 1 ]; then restore_usb || echo USB_RESTORE_FAILED; fi
    if [ "$rc" != 0 ]; then echo "RELOAD_FAILED code=$rc; do not enable TX; inspect this log."; fi
    exit "$rc"
}
trap finish 0
echo PREFLIGHT
[ "${1:-}" = '--confirmed-attenuated-loopback' ] || {
    echo 'Requires confirmed TX1 -> 30 dB attenuator -> RX2 connection.' >&2
    exit 2
}
firmware=/lib/firmware/pluto_pcm_fm.bit.bin
expected=7d4c06da4e1387f05e5d982299e4db2ff012f35cabd4c784a9aedfcd089a6fbd
printf '%s  %s\n' "$expected" "$firmware" | sha256sum -c -
[ "$(cat /sys/class/fpga_manager/fpga0/state)" = operating ]
phy=/sys/bus/iio/devices/iio:device0
[ "$(cat "$phy/name")" = ad9361-phy ]
for d in /sys/bus/iio/devices/iio:device*/buffer/enable; do
    [ "$(cat "$d")" = 0 ] || { echo "Active IIO buffer: $d" >&2; exit 1; }
done
for driver in cf_axi_adc cf_axi_dds dma-axi-dmac xiic-i2c; do
    test -w /sys/bus/platform/drivers/$driver/unbind
    test -w /sys/bus/platform/drivers/$driver/bind
done
test -L /sys/bus/platform/devices/41600000.i2c/driver
# Preserve the PHY driver/configuration; mute both available TX channels.
for gain in "$phy"/out_voltage*_hardwaregain; do
    printf '%s\n' -89.75 > "$gain"
    grep -q -- '-89.750000' "$gain"
done
for name in /sys/bus/iio/devices/iio:device*/name; do
    if [ "$(cat "$name")" = cf-ad9361-dds-core-lpc ]; then
        d=${name%/name}
        for raw in "$d"/out_altvoltage*_raw; do printf '0\n' > "$raw"; done
    fi
done
# Keep the AD9361 sample clocks running for driver teardown/reinitialization.
printf 'fdd\n' > "$phy/ensm_mode"
echo USB_STOP
usb_stopped=1
printf '\n' > "$gadget/UDC"
killall iiod
sleep 1
if pidof iiod >/dev/null; then echo 'iiod did not stop' >&2; exit 1; fi
echo UNBIND_CONSUMERS
printf '%s\n' 79020000.cf-ad9361-lpc > /sys/bus/platform/drivers/cf_axi_adc/unbind
printf '%s\n' 79024000.cf-ad9361-dds-core-lpc > /sys/bus/platform/drivers/cf_axi_dds/unbind
printf '%s\n' 7c400000.dma > /sys/bus/platform/drivers/dma-axi-dmac/unbind
printf '%s\n' 7c420000.dma > /sys/bus/platform/drivers/dma-axi-dmac/unbind
printf '%s\n' 41600000.i2c > /sys/bus/platform/drivers/xiic-i2c/unbind
echo FPGA_LOAD
printf '0\n' > /sys/class/fpga_manager/fpga0/flags
printf 'pluto_pcm_fm.bit.bin\n' > /sys/class/fpga_manager/fpga0/firmware
[ "$(cat /sys/class/fpga_manager/fpga0/state)" = operating ]
echo FPGA_OPERATING
# Restore sample clocks while retaining maximum RF attenuation.
printf 'fdd\n' > "$phy/ensm_mode"
printf '%s\n' 41600000.i2c > /sys/bus/platform/drivers/xiic-i2c/bind
printf '%s\n' 7c400000.dma > /sys/bus/platform/drivers/dma-axi-dmac/bind
printf '%s\n' 7c420000.dma > /sys/bus/platform/drivers/dma-axi-dmac/bind
printf '%s\n' 79024000.cf-ad9361-dds-core-lpc > /sys/bus/platform/drivers/cf_axi_dds/bind
printf '%s\n' 79020000.cf-ad9361-lpc > /sys/bus/platform/drivers/cf_axi_adc/bind
echo DRIVERS_BOUND
# Keep PCM-FM selection off, disable DDS tones after driver initialization.
test "$(devmem 0x41210000 32)" = 0x00000000
for name in /sys/bus/iio/devices/iio:device*/name; do
    if [ "$(cat "$name")" = cf-ad9361-dds-core-lpc ]; then
        d=${name%/name}
        for raw in "$d"/out_altvoltage*_raw; do printf '0\n' > "$raw"; done
    fi
done
printf 'sleep\n' > "$phy/ensm_mode"
restore_usb
usb_stopped=0
pidof iiod
cat /sys/class/fpga_manager/fpga0/state
for name in /sys/bus/iio/devices/iio:device*/name; do cat "$name"; done
trap - 0
echo 'TEMPORARY_LOAD_DONE: PCM-FM disabled, radio asleep. RF test is a separate step.'
