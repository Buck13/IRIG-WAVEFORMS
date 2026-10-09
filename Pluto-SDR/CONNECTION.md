# Pluto USB connection — 2026-10-01

The official ADI driver installer v0.9 was installed by the user.

Verified:
- Direct USB IIO driver: OK.
- Serial console COM3: login and diagnostic commands succeeded.
- libiio 0.26 created a USB context and read the device inventory.
- Receive-only capture: 1024 complex samples, 4096 bytes, exit code 0.
- No firmware flashing or transmit test was performed.

Device-reported firmware: v0.33-3-gd382-dirty.
Device-reported model: Analog Devices PlutoSDR Rev.C (Z7010-AD9361).
This firmware string is not independent verification of the physical board/chips.

USB network (RNDIS) driver is installed but still reports Windows code 43.
Direct USB libiio access works independently of that network interface.

Local tools: libiio-v0.26/Windows-VS-2022-x64/
Run iio_info.exe -s to discover the current USB URI (it can change on reconnect).
The tested URI was usb:2.9.5.
Run iio_info.exe -u <current-URI> to read the device information.

Logs: iio-usb-info.txt
Receive data: rx-usb-test.bin (interleaved signed 16-bit I/Q; existing radio settings).
Original device configuration/information: config-original.txt, device-info-original.html.
Official driver repository: https://github.com/analogdevicesinc/plutosdr-m2k-drivers-win
Official diagnostic tools: https://github.com/analogdevicesinc/libiio/releases/tag/v0.26
