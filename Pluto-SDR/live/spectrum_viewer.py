"""Continuous receive-only spectrum GUI; start/stop RX never enables TX."""
import sys,time,threading,argparse
import numpy as np
from PySide6 import QtCore,QtWidgets,QtGui
import pyqtgraph as pg
from rx_backend import Receiver,spectrum

class Reader(QtCore.QThread):
    error=QtCore.Signal(str)
    def __init__(self,uri,rx):
        super().__init__();self.uri=uri;self.rx=rx;self.stop_event=threading.Event();self.lock=threading.Lock();self.latest=None
    def run(self):
        receiver=None
        try:
            receiver=Receiver(self.uri,self.rx);fs,lo=receiver.settings();last=0;check=0;avg=None
            while not self.stop_event.is_set():
                z=receiver.capture();now=time.monotonic()
                if now-check>1:
                    new_fs,new_lo=receiver.settings()
                    if (new_fs,new_lo)!=(fs,lo):avg=None
                    fs,lo=new_fs,new_lo;check=now
                if now-last<.08:continue
                power=spectrum(z);avg=power if avg is None else .8*avg+.2*power
                with self.lock:self.latest=(fs,lo,10*np.log10(np.maximum(avg,1e-16)),float(np.sqrt(np.mean(abs(z)**2))),int(np.sum((abs(z.real)>=2047)|(abs(z.imag)>=2047))))
                last=now
        except Exception as e:self.error.emit(str(e))
        finally:
            if receiver:receiver.close()

class Window(QtWidgets.QMainWindow):
    def __init__(self,uri):
        super().__init__();self.worker=None;self.hold=None;self.tuning=None
        QtGui.QFontDatabase.addApplicationFont('C:/Windows/Fonts/segoeui.ttf')
        QtWidgets.QApplication.instance().setFont(QtGui.QFont('Segoe UI',10))
        self.setWindowTitle('Pluto live spectrum — RECEIVE ONLY');self.resize(1050,650)
        box=QtWidgets.QWidget();self.setCentralWidget(box);layout=QtWidgets.QVBoxLayout(box)
        bar=QtWidgets.QHBoxLayout();layout.addLayout(bar)
        self.uri=QtWidgets.QLineEdit(uri);bar.addWidget(self.uri)
        self.rx=QtWidgets.QComboBox();self.rx.addItems(['RX1','RX2']);self.rx.setCurrentIndex(1);bar.addWidget(self.rx)
        self.start=QtWidgets.QPushButton('Start RX');self.start.clicked.connect(self.connect_rx);bar.addWidget(self.start)
        self.stop=QtWidgets.QPushButton('Stop RX');self.stop.clicked.connect(self.disconnect_rx);bar.addWidget(self.stop)
        self.maxhold=QtWidgets.QCheckBox('Max hold');bar.addWidget(self.maxhold)
        reset=QtWidgets.QPushButton('Clear hold');reset.clicked.connect(lambda:setattr(self,'hold',None));bar.addWidget(reset)
        self.plot=pg.PlotWidget();layout.addWidget(self.plot);self.plot.setLabel('bottom','RF frequency',units='MHz');self.plot.getAxis('bottom').enableAutoSIPrefix(False);self.plot.setLabel('left','dBFS / FFT bin');self.plot.setYRange(-120,0);self.plot.showGrid(x=True,y=True,alpha=.2)
        self.trace=self.plot.plot(pen=pg.mkPen('#36c5f0',width=1.5));self.held=self.plot.plot(pen=pg.mkPen('#ffc857',width=1))
        self.status=QtWidgets.QLabel('Disconnected. RX controls never start or stop TX.');layout.addWidget(self.status)
        layout.addWidget(QtWidgets.QLabel('8192-point Hann FFT • power averaging • relative ADC level, not calibrated dBm • TX is controlled separately through SSH'))
        self.timer=QtCore.QTimer();self.timer.timeout.connect(self.refresh);self.timer.start(80)
    def connect_rx(self):
        if self.worker and self.worker.isRunning():return
        self.hold=None;self.worker=Reader(self.uri.text(),self.rx.currentIndex()+1)
        self.worker.error.connect(self.status.setText);self.worker.start();self.start.setEnabled(False);self.rx.setEnabled(False);self.uri.setEnabled(False)
        self.status.setText('Connecting to receiver…')
    def disconnect_rx(self):
        if self.worker:
            self.worker.stop_event.set()
            if not self.worker.wait(5000):self.status.setText('Waiting for RX to stop…');return False
            self.worker=None
        self.start.setEnabled(True);self.rx.setEnabled(True);self.uri.setEnabled(True);self.status.setText('RX stopped. TX state is unchanged.');return True
    def refresh(self):
        if not self.worker:return
        if not self.worker.isRunning():self.start.setEnabled(True);self.rx.setEnabled(True);self.uri.setEnabled(True)
        with self.worker.lock:data=self.worker.latest;self.worker.latest=None
        if data is None:return
        fs,lo,y,rms,clipped=data;x=(lo+np.fft.fftshift(np.fft.fftfreq(len(y),1/fs)))/1e6
        if self.tuning!=(fs,lo):self.hold=None;self.tuning=(fs,lo)
        self.trace.setData(x,y);self.plot.setXRange(x[0],x[-1],padding=0)
        self.hold=y.copy() if self.hold is None else np.maximum(self.hold,y)
        self.held.setData(x,self.hold if self.maxhold.isChecked() else np.full_like(y,np.nan))
        self.status.setText(f'{self.rx.currentText()} • {fs/1e6:.3f} MS/s • LO {lo/1e6:.6f} MHz • RMS {rms:.2f} counts • clipped {clipped} / {len(y)}')
    def closeEvent(self,event):
        if self.disconnect_rx():event.accept()
        else:event.ignore()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--uri',default='ip:192.168.2.1');parser.add_argument('--smoke-test',action='store_true');args=parser.parse_args()
    app=QtWidgets.QApplication(sys.argv[:1]);win=Window(args.uri);win.show()
    if args.smoke_test:QtCore.QTimer.singleShot(800,win.close)
    sys.exit(app.exec())
