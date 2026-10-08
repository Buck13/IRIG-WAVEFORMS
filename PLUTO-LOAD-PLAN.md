# PN15/BPSK loading and loopback preparation

## Completed hardware milestone — 2026-10-08

The corrected detached loader successfully programmed the FPGA temporarily and
restored USB plus both IIO radio drivers. It now explicitly unbinds/rebinds UDC,
starts IIO as a background service, and attempts USB recovery on errors.
Use nohup + setsid with redirected log/stdin when launching it; a foreground
SSH command is unsuitable because this action interrupts USB networking.

TX1 → 30 dB attenuator → RX2 was confirmed and tested. FPGA-generated PN15/BPSK
matched the reference with zero mismatches in 126975 analyzed symbols, including
118783 held-out symbols. See captures/pn15-hardware-20261008-183726/RESULT.md.
Source select and DDS are off, and both TX gains read -89.75 dB at completion.
Flash is unchanged. The sections below retain earlier preparation history.

## Device inspection, 2026-10-03

Staging completed: the verified `pluto_pn15.bit.bin` is now in the device's
RAM-backed `/lib/firmware`. SHA-256 on both sides is
`6e90782634a8452d1a019534bd96c1649320b9ae82e5c404ace765d867dbcf40`.
SSH host identity was verified against the public key read over USB serial.
The candidate loader `load-pn15-temporary.sh` was copied to `/tmp` and passed
`sh -n` on the device. It has NOT been executed. Driver unbind/rebind and
actual FPGA Manager loading remain untested. The user's attenuated RF
connection confirmation is pending. No flash writes have occurred.

Read-only console inspection found Linux 5.4.0-gb05d16429dac-dirty and an
operating Xilinx Zynq FPGA Manager. `/sys/class/fpga_manager/fpga0/firmware`
is writable; `/dev/xdevcfg` is absent. USB IIO and network discovery work.
The USB URI changes on reconnect; rediscover rather than hard-code it.

Flash partitions: mtd0 bootloader, mtd1 environment, mtd2 nvmfs, mtd3 Linux.
None have been written. A temporary FPGA Manager load is the preferred first
experiment; a power cycle should restore the FPGA image in existing firmware.
This recovery route has not yet been tested with the custom design.

Relevant active platform drivers:

| Device | Driver |
|---|---|
| 79020000.cf-ad9361-lpc | cf_axi_adc |
| 79024000.cf-ad9361-dds-core-lpc | cf_axi_dds |
| 7c400000.dma | dma-axi-dmac |
| 7c420000.dma | dma-axi-dmac |
| 41600000.i2c | xiic-i2c |

## Loading sequence to validate

1. Finish full implementation timing/DRC validation and hash exported files.
2. Convert the .bit with AMD Bootgen for Zynq FPGA Manager. Do not assume the
   Vivado raw .bin has the same byte order as Bootgen's processed .bit.bin.
3. Confirm board pinout, transfer the processed file into RAM-backed
   `/lib/firmware`, and verify its hash on the device.
4. Stop IIO clients/daemon and all DMA activity. Mute TX. Quiesce/unbind FPGA
   consumers before DMA providers; account for FPGA I2C as well. Confirm the
   installed drivers support unbind/rebind before attempting this.
5. Request a full load with FPGA Manager, verify state and kernel messages,
   then rebind providers before consumers and recheck IIO access/calibration.
6. Keep source selection at its default zero (DMA bypass) until the radio is
   initialized. The custom AXI GPIO data register at 0x41210000 selects PN15
   when bit 0 is one. Do not access this address on the original FPGA image.

These are preparation steps, not a verified reload script. No firmware or
FPGA programming has been performed. A .bit/.bin is not a USB-update .frm.

## RF test

The user has a 20 dB external attenuator and no separate receiver/analyser.
Use a cabled TX-to-attenuator-to-RX test after confirming the cable and
attenuator frequency/power ratings. Start with large radio TX attenuation and
low manual RX gain; inspect clipping before increasing signal level. No TX
settings have been applied. An antenna test is not needed for this milestone.

Capture the hardware PN15/BPSK signal, check spectrum and I/Q, then compare
recovered symbol signs against the PN15 reference allowing for phase, delay,
and filter transients. Shared-device loopback demonstrates this signal path;
it is not an independent RF conformance test.

References:
- https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841645/Solution+Zynq+PL+Programming+With+FPGA+Manager
- https://github.com/analogdevicesinc/plutosdr-fw
