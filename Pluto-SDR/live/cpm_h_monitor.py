"""Live CPM-H spectrum, TX control, and FPGA acquisition monitor."""
from pathlib import Path
import argparse
import re
import subprocess
import sys
import threading

from PySide6 import QtCore, QtGui, QtWidgets

from spectrum_viewer import Window as SpectrumWindow


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TX_SCRIPT = ROOT / "Pluto-SDR" / "cpm-h" / "tx_cpm_h_dma.py"
PLINK = Path("C:/Program Files (x86)/PuTTY/plink.exe")
DEFAULT_HOST_KEY = "SHA256:FDJU9CDSzLIEd0b+2ccDiP42vFPGNlB2KWvV/xu4O0o"


def ssh_args(host_key, command):
    return [str(PLINK), "-ssh", "-batch", "-hostkey", host_key,
            "-pw", "analog", "root@192.168.2.1", command]


class AcquisitionMonitor(QtCore.QThread):
    result = QtCore.Signal(int, str)
    error = QtCore.Signal(str)

    def __init__(self, host_key):
        super().__init__()
        self.host_key = host_key
        self.stop_event = threading.Event()

    def run(self):
        while not self.stop_event.is_set():
            try:
                completed = subprocess.run(
                    ssh_args(self.host_key, "/tmp/cpm-h-rx-control.sh auto"),
                    capture_output=True, text=True, timeout=20,
                    creationflags=subprocess.CREATE_NO_WINDOW)
                text = (completed.stdout + completed.stderr).strip()
                match = re.search(r"PN15-errors=(\d+)/64", text)
                if completed.returncode or not match:
                    raise RuntimeError(text or "automatic acquisition failed")
                self.result.emit(int(match.group(1)), text)
            except Exception as exc:
                self.error.emit(str(exc))
            self.stop_event.wait(0.5)


class CpmWindow(SpectrumWindow):
    def __init__(self, uri, host_key):
        super().__init__(uri)
        self.setWindowTitle("Pluto CPM-H loopback monitor")
        self.tx_process = None
        self.acquisition = None

        panel = QtWidgets.QHBoxLayout()
        self.centralWidget().layout().insertLayout(0, panel)
        panel.addWidget(QtWidgets.QLabel("CPM-H TX"))

        self.led = QtWidgets.QLabel("●  IDLE")
        self.led.setMinimumWidth(120)
        self.set_led("#9aa0a6", "IDLE")
        panel.addWidget(self.led)

        panel.addWidget(QtWidgets.QLabel("Data rate kbit/s"))
        self.rate = QtWidgets.QDoubleSpinBox()
        self.rate.setRange(130.209, 500.0)
        self.rate.setDecimals(3)
        self.rate.setSingleStep(25)
        self.rate.setValue(500)
        self.rate.setToolTip("32 samples/dibit. 500 kbit/s is the verified maximum for this image.")
        panel.addWidget(self.rate)

        panel.addWidget(QtWidgets.QLabel("Center MHz"))
        self.tx_frequency = QtWidgets.QDoubleSpinBox()
        self.tx_frequency.setRange(70, 6000)
        self.tx_frequency.setDecimals(3)
        self.tx_frequency.setValue(915)
        panel.addWidget(self.tx_frequency)

        panel.addWidget(QtWidgets.QLabel("TX gain dB"))
        self.tx_gain = QtWidgets.QDoubleSpinBox()
        self.tx_gain.setRange(-89.75, -10)
        self.tx_gain.setDecimals(2)
        self.tx_gain.setValue(-30)
        panel.addWidget(self.tx_gain)

        self.tx_start = QtWidgets.QPushButton("Start continuous TX")
        self.tx_start.clicked.connect(self.start_tx)
        panel.addWidget(self.tx_start)
        self.tx_stop = QtWidgets.QPushButton("Stop TX")
        self.tx_stop.clicked.connect(self.stop_tx)
        self.tx_stop.setEnabled(False)
        panel.addWidget(self.tx_stop)

        panel.addWidget(QtWidgets.QLabel("SSH key"))
        self.host_key = QtWidgets.QLineEdit(host_key)
        self.host_key.setMinimumWidth(260)
        panel.addWidget(self.host_key, 1)

        self.rx.setCurrentIndex(1)
        self.maxhold.setChecked(True)
        self.status.setText("Ready. Requires TX1 → 30 dB attenuator → RX2.")

    def set_led(self, color, text):
        self.led.setText(f"●  {text}")
        self.led.setStyleSheet(f"color:{color};font-weight:700;font-size:15px")

    def configure_radio(self, sample_rate, bandwidth, frequency):
        command = (
            "p=/sys/bus/iio/devices/iio:device0; "
            "echo fdd > $p/ensm_mode; "
            f"echo {sample_rate} > $p/in_voltage_sampling_frequency; "
            f"echo {sample_rate} > $p/out_voltage_sampling_frequency; "
            f"echo {bandwidth} > $p/in_voltage_rf_bandwidth; "
            f"echo {bandwidth} > $p/out_voltage_rf_bandwidth; "
            f"echo {frequency} > $p/out_altvoltage0_RX_LO_frequency; "
            f"echo {frequency} > $p/out_altvoltage1_TX_LO_frequency; "
            "echo manual > $p/in_voltage1_gain_control_mode; "
            "echo 30 > $p/in_voltage1_hardwaregain; "
            "/tmp/cpm-h-rx-control.sh stop")
        result = subprocess.run(ssh_args(self.host_key.text().strip(), command),
                                capture_output=True, text=True, timeout=15,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:
            raise RuntimeError((result.stderr or result.stdout).strip())

    def start_tx(self):
        if self.tx_process is not None:
            return
        rate = self.rate.value() * 1000.0
        sample_rate = int(round(rate * 16.0))
        bandwidth = int(min(3_000_000, max(1_000_000, sample_rate * 0.375)))
        frequency = int(round(self.tx_frequency.value() * 1e6))
        try:
            self.configure_radio(sample_rate, bandwidth, frequency)
        except Exception as exc:
            self.set_led("#ff4d4f", "ERROR")
            self.status.setText(str(exc))
            return

        usable_span = sample_rate * 0.75 / 1e6
        center = frequency / 1e6
        self.start_freq.setValue(center - usable_span / 2)
        self.stop_freq.setValue(center + usable_span / 2)
        self.sample_rate.setValue(sample_rate / 1e6)
        self.rf_bandwidth.setValue(bandwidth / 1e6)

        self.tx_process = QtCore.QProcess(self)
        self.tx_process.setProgram(sys.executable)
        self.tx_process.setArguments([
            str(TX_SCRIPT), "--uri", self.uri.text(),
            "--frequency", str(frequency), "--sample-rate", str(sample_rate),
            "--rf-bandwidth", str(bandwidth), "--tx-gain", str(self.tx_gain.value()),
            "--samples-per-dibit", "32"])
        self.tx_process.setProcessChannelMode(QtCore.QProcess.MergedChannels)
        self.tx_process.readyReadStandardOutput.connect(self.tx_output)
        self.tx_process.finished.connect(self.tx_finished)
        self.tx_process.start()
        if not self.tx_process.waitForStarted(5000):
            self.status.setText("Could not start the DMA transmitter.")
            self.tx_process = None
            return

        self.tx_start.setEnabled(False)
        self.tx_stop.setEnabled(True)
        for control in (self.rate, self.tx_frequency, self.tx_gain, self.host_key):
            control.setEnabled(False)
        self.set_led("#ffbf00", "ACQUIRING")
        if not self.worker or not self.worker.isRunning():
            self.connect_rx()
        self.acquisition = AcquisitionMonitor(self.host_key.text().strip())
        self.acquisition.result.connect(self.acquisition_result)
        self.acquisition.error.connect(self.acquisition_error)
        self.acquisition.start()

    def tx_output(self):
        if self.tx_process:
            text = bytes(self.tx_process.readAllStandardOutput()).decode(errors="replace").strip()
            if text:
                self.status.setText(text.splitlines()[-1])

    def acquisition_result(self, errors, text):
        if errors <= 2:
            self.set_led("#20c77a", f"LOCKED  {errors}/64")
        else:
            self.set_led("#ff4d4f", f"NO LOCK  {errors}/64")
        self.status.setToolTip(text)

    def acquisition_error(self, text):
        self.set_led("#ff4d4f", "MONITOR ERROR")
        self.status.setToolTip(text)

    def stop_tx(self):
        if self.acquisition:
            self.acquisition.stop_event.set()
            self.acquisition.wait(22000)
            self.acquisition = None
        if self.tx_process:
            self.tx_process.terminate()
            if not self.tx_process.waitForFinished(3000):
                self.tx_process.kill()
                self.tx_process.waitForFinished(2000)
            self.tx_process = None
        try:
            command = ("/tmp/cpm-h-rx-control.sh stop; "
                       "p=/sys/bus/iio/devices/iio:device0; "
                       "echo -89.75 > $p/out_voltage0_hardwaregain; echo sleep > $p/ensm_mode")
            subprocess.run(ssh_args(self.host_key.text().strip(), command),
                           capture_output=True, timeout=10,
                           creationflags=subprocess.CREATE_NO_WINDOW)
        except Exception:
            pass
        self.tx_start.setEnabled(True)
        self.tx_stop.setEnabled(False)
        for control in (self.rate, self.tx_frequency, self.tx_gain, self.host_key):
            control.setEnabled(True)
        self.set_led("#9aa0a6", "IDLE")
        self.status.setText("TX stopped and muted.")

    def tx_finished(self):
        if self.tx_process and self.tx_process.exitStatus() == QtCore.QProcess.CrashExit:
            self.set_led("#ff4d4f", "TX ERROR")

    def closeEvent(self, event):
        self.stop_tx()
        super().closeEvent(event)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", default="ip:192.168.2.1")
    parser.add_argument("--host-key", default=DEFAULT_HOST_KEY)
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()
    app = QtWidgets.QApplication(sys.argv[:1])
    window = CpmWindow(args.uri, args.host_key)
    window.show()
    if args.smoke_test:
        QtCore.QTimer.singleShot(1000, window.close)
    sys.exit(app.exec())
