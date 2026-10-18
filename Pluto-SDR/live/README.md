# Live spectrum and manual continuous PCM-FM TX

The viewer is receive-only. Starting/stopping/closing it does not control TX.
The SSH controller starts an independent cyclic TX stream on the Pluto.
**Continuous TX stays on after closing PuTTY or the viewer. Use the stop command.**

## 1. Cables and one-time Python setup

USB: PC -> Pluto. RF: TX1 -> 30 dB attenuator -> RX2.
In Windows PowerShell:

```powershell
cd C:\SDR_Work\IRIG-WAVEFORMS
& .\.venv\Scripts\python.exe -m pip install -r .\Pluto-SDR\live\requirements.txt
```

Dependencies are already installed on this PC.

## 2. Load PCM-FM and prepare the radio (once after each power cycle)

Close the spectrum viewer and other RX/TX applications first. In PowerShell:

```powershell
& .\.venv\Scripts\python.exe .\Pluto-SDR\live\setup_device.py
```

This copies the verified bitstream and scripts, reloads FPGA RAM (not flash),
waits for USB recovery and prepares 915 MHz, 2.5 MS/s, 1 MHz RF bandwidth,
manual RX gain 30 dB. Both TX channels remain at maximum attenuation.
Do not use the BPSK capture script during this process.

The saved SSH fingerprint for the current boot was verified over the direct USB
connection on 2026-10-18:
`SHA256:XE9VZSZUPrwq6aTkbb8pEP2lUThVIj8LuEbtBOhChUA`.
A host-key mismatch stops setup. Reverify through USB serial, then pass
`--host-key SHA256:...`; do not blindly accept another key.
The firmware's FPGA-manager filename attribute is write-only, so the controller
relies on the verified load log and payload hash. An independent FPGA reload
invalidates that assumption; rerun setup before using the controls.

## 3. Open continuous spectrum monitoring

Double-click `Open-Spectrum.cmd` in this folder, or run:

```powershell
& .\.venv\Scripts\python.exe .\Pluto-SDR\live\spectrum_viewer.py
```

Leave URI `ip:192.168.2.1`, select RX2, choose a center and span, and click
**Start RX**. A span within the instantaneous sample bandwidth gives a fast
continuous FFT. A wider span sweeps the RX LO across the requested range and
stitches the FFT sections; it updates more slowly. The default is 915 MHz with
a 20 MHz span. The viewer may retune RX only; it never retunes or enables TX.
Levels are relative dBFS per FFT bin, not calibrated RF dBm. Only one program
can own the RX buffer; stop the viewer before running the older capture script.
**Stop RX** releases the receiver only. It does not turn transmission off.

## 4. Open SSH in PuTTY

- Host: `192.168.2.1`; connection SSH; port 22.
- Login: `root`; password on this board: `analog`.
- This is USB networking; no Ethernet cable required.

Alternative: PuTTY Serial, COM3 (verify in Device Manager), 115200 baud,
8 data bits, no parity, 1 stop bit, no flow control. Same login and commands.

## 5. Start continuous FPGA PN15 -> PCM-FM

In the Pluto's SSH/serial console:

```sh
sh /tmp/pcm-fm-control.sh start --attenuated-loopback
```

It starts a zero-filled cyclic DMA buffer on the ARM, selects FPGA PCM-FM,
and sets TX1 attenuation to 40 dB (hardwaregain -40 dB). TX2 stays muted.
FPGA PN15/modulation supply the actual waveform; DMA zeros keep the TX path
active. No PC payload streaming is needed. The viewer should show the signal.

Read status:

```sh
sh /tmp/pcm-fm-control.sh status
```

Source `0x00000001` and TX buffer `1` indicate an active selected stream.
A second start is refused when a TX buffer is already active.

## 6. Stop transmission

```sh
sh /tmp/pcm-fm-control.sh stop
```

This maximizes TX attenuation, deselects FPGA PCM-FM and terminates the specific
stream process started by this controller. Verify with `status`: source 0,
TX buffer 0 and TX1 gain -89.75 dB. The viewer may keep receiving noise.
If another application owns the TX buffer, close that application too.

To change the fixed test configuration, stop TX and RX first. `prepare` restores
the tested configuration and leaves TX muted:

```sh
sh /tmp/pcm-fm-control.sh prepare
```

Power cycling removes the temporary bitstream/scripts and requires setup again.

## Validation status

The post-interpolator image passed timing and DRC, preserved selector-0 DMA on
hardware, and transmitted selector-1 PN15 PCM-FM through TX1 -> 30 dB -> RX2.
The persistent controller and full reload helper have both completed end to end.
The current FPGA load is volatile and must be repeated after a power cycle.
