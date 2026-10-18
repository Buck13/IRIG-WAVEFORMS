"""Continuous receive-only spectrum GUI with optional swept wide-band view."""
import sys,time,threading,argparse
import numpy as np
from PySide6 import QtCore,QtWidgets,QtGui
import pyqtgraph as pg
from rx_backend import Receiver,spectrum

class Reader(QtCore.QThread):
    error=QtCore.Signal(str)
    def __init__(self,uri,rx,center_mhz,span_mhz,sample_rate_msps,rf_bandwidth_mhz):
        super().__init__();self.uri=uri;self.rx=rx;self.center=center_mhz*1e6;self.span=span_mhz*1e6;self.sample_rate=sample_rate_msps*1e6;self.rf_bandwidth=rf_bandwidth_mhz*1e6;self.stop_event=threading.Event();self.lock=threading.Lock();self.latest=None
    def run(self):
        receiver=None
        try:
            receiver=Receiver(self.uri,self.rx,sample_rate=self.sample_rate,rf_bandwidth=self.rf_bandwidth);fs,_,bw=receiver.settings();last=0;avg=None
            wide=self.span>fs*.9
            usable=fs*.8
            count=1 if not wide else 2*int(np.ceil(max(0,self.span-usable)/(2*usable*.75)))+1
            centers=np.linspace(self.center-self.span/2+usable/2,self.center+self.span/2-usable/2,count) if wide else np.array([self.center])
            while not self.stop_event.is_set():
                xs=[];ys=[];rms=[];clipped=0
                for lo in centers:
                    if self.stop_event.is_set():break
                    receiver.set_rx_lo(lo);receiver.capture();z=receiver.capture()
                    freq=lo+np.fft.fftshift(np.fft.fftfreq(len(z),1/fs));power=spectrum(z)
                    keep=(abs(freq-lo)<=usable/2) if wide else np.ones(len(z),dtype=bool)
                    xs.append(freq[keep]/1e6);ys.append(power[keep]);rms.append(np.sqrt(np.mean(abs(z)**2)));clipped+=int(np.sum((abs(z.real)>=2047)|(abs(z.imag)>=2047)))
                if not xs:break
                x=np.concatenate(xs);power=np.concatenate(ys);order=np.argsort(x);x=x[order];power=power[order]
                avg=power if avg is None or len(avg)!=len(power) else .8*avg+.2*power
                now=time.monotonic()
                if now-last<.08:continue
                mode=f'sweep {self.span/1e6:g} MHz' if wide else 'live'
                with self.lock:self.latest=(x,10*np.log10(np.maximum(avg,1e-16)),fs,bw,self.center,mode,float(max(rms)),clipped)
                last=now
        except Exception as e:self.error.emit(str(e))
        finally:
            if receiver:
                try:receiver.set_rx_lo(self.center)
                except Exception:pass
                receiver.close()

class Window(QtWidgets.QMainWindow):
    def __init__(self,uri):
        super().__init__();self.worker=None;self.hold=None;self.tuning=None
        QtGui.QFontDatabase.addApplicationFont('C:/Windows/Fonts/segoeui.ttf')
        QtWidgets.QApplication.instance().setFont(QtGui.QFont('Segoe UI',10))
        self.setWindowTitle('Pluto live spectrum — RECEIVE ONLY');self.resize(1320,650)
        box=QtWidgets.QWidget();self.setCentralWidget(box);layout=QtWidgets.QVBoxLayout(box)
        bar=QtWidgets.QHBoxLayout();layout.addLayout(bar)
        self.uri=QtWidgets.QLineEdit(uri);bar.addWidget(self.uri)
        self.rx=QtWidgets.QComboBox();self.rx.addItems(['RX1','RX2']);self.rx.setCurrentIndex(1);bar.addWidget(self.rx)
        bar.addWidget(QtWidgets.QLabel('Center MHz'))
        self.center=QtWidgets.QDoubleSpinBox();self.center.setRange(70,6000);self.center.setDecimals(3);self.center.setValue(915);bar.addWidget(self.center)
        bar.addWidget(QtWidgets.QLabel('Span MHz'))
        self.span=QtWidgets.QDoubleSpinBox();self.span.setRange(1,100);self.span.setDecimals(1);self.span.setValue(20);bar.addWidget(self.span)
        bar.addWidget(QtWidgets.QLabel('ADC MS/s'))
        self.sample_rate=QtWidgets.QDoubleSpinBox();self.sample_rate.setRange(2.083333,30.72);self.sample_rate.setDecimals(6);self.sample_rate.setValue(2.5);bar.addWidget(self.sample_rate)
        self.sample_rate.setToolTip('Complex RX sample rate. The Pluto may quantize the requested value.')
        bar.addWidget(QtWidgets.QLabel('RX BW MHz'))
        self.rf_bandwidth=QtWidgets.QDoubleSpinBox();self.rf_bandwidth.setRange(.2,20);self.rf_bandwidth.setDecimals(3);self.rf_bandwidth.setValue(1);bar.addWidget(self.rf_bandwidth)
        self.rf_bandwidth.setToolTip('AD9361 receive baseband filter bandwidth.')
        self.start=QtWidgets.QPushButton('Start RX');self.start.clicked.connect(self.connect_rx);bar.addWidget(self.start)
        self.stop=QtWidgets.QPushButton('Stop RX');self.stop.clicked.connect(self.disconnect_rx);bar.addWidget(self.stop)
        self.maxhold=QtWidgets.QCheckBox('Max hold');bar.addWidget(self.maxhold)
        reset=QtWidgets.QPushButton('Clear hold');reset.clicked.connect(lambda:setattr(self,'hold',None));bar.addWidget(reset)
        self.plot=pg.PlotWidget();layout.addWidget(self.plot);self.plot.setLabel('bottom','RF frequency',units='MHz');self.plot.getAxis('bottom').enableAutoSIPrefix(False);self.plot.setLabel('left','dBFS / FFT bin');self.plot.setYRange(-120,0);self.plot.showGrid(x=True,y=True,alpha=.2)
        self.trace=self.plot.plot(pen=pg.mkPen('#36c5f0',width=1.5));self.held=self.plot.plot(pen=pg.mkPen('#ffc857',width=1))
        self.status=QtWidgets.QLabel('Disconnected. RX controls never start or stop TX.');layout.addWidget(self.status)
        layout.addWidget(QtWidgets.QLabel('Wide spans sweep RX tuning and update more slowly • relative ADC level, not calibrated dBm • TX is controlled separately through SSH'))
        self.timer=QtCore.QTimer();self.timer.timeout.connect(self.refresh);self.timer.start(80)
    def connect_rx(self):
        if self.worker and self.worker.isRunning():return
        self.hold=None;self.worker=Reader(self.uri.text(),self.rx.currentIndex()+1,self.center.value(),self.span.value(),self.sample_rate.value(),self.rf_bandwidth.value())
        self.worker.error.connect(self.status.setText);self.worker.start();self.start.setEnabled(False);self.rx.setEnabled(False);self.uri.setEnabled(False)
        self.center.setEnabled(False);self.span.setEnabled(False);self.sample_rate.setEnabled(False);self.rf_bandwidth.setEnabled(False)
        self.status.setText('Connecting to receiver…')
    def disconnect_rx(self):
        if self.worker:
            self.worker.stop_event.set()
            if not self.worker.wait(5000):self.status.setText('Waiting for RX to stop…');return False
            self.worker=None
        self.start.setEnabled(True);self.rx.setEnabled(True);self.uri.setEnabled(True);self.center.setEnabled(True);self.span.setEnabled(True);self.sample_rate.setEnabled(True);self.rf_bandwidth.setEnabled(True);self.status.setText('RX stopped. TX state is unchanged.');return True
    def refresh(self):
        if not self.worker:return
        if not self.worker.isRunning():self.start.setEnabled(True);self.rx.setEnabled(True);self.uri.setEnabled(True);self.center.setEnabled(True);self.span.setEnabled(True);self.sample_rate.setEnabled(True);self.rf_bandwidth.setEnabled(True)
        with self.worker.lock:data=self.worker.latest;self.worker.latest=None
        if data is None:return
        x,y,fs,bw,center,mode,rms,clipped=data
        if self.tuning!=(fs,center,len(x)):self.hold=None;self.tuning=(fs,center,len(x))
        self.trace.setData(x,y);self.plot.setXRange(x[0],x[-1],padding=0)
        self.hold=y.copy() if self.hold is None else np.maximum(self.hold,y)
        self.held.setData(x,self.hold if self.maxhold.isChecked() else np.full_like(y,np.nan))
        self.status.setText(f'{self.rx.currentText()} • {mode} • center {center/1e6:.3f} MHz • ADC {fs/1e6:.3f} MS/s • RX BW {bw/1e6:.3f} MHz • peak RMS {rms:.2f} • clipped {clipped}')
    def closeEvent(self,event):
        if self.disconnect_rx():event.accept()
        else:event.ignore()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--uri',default='ip:192.168.2.1');parser.add_argument('--smoke-test',action='store_true');args=parser.parse_args()
    app=QtWidgets.QApplication(sys.argv[:1]);win=Window(args.uri);win.show()
    if args.smoke_test:QtCore.QTimer.singleShot(800,win.close)
    sys.exit(app.exec())
