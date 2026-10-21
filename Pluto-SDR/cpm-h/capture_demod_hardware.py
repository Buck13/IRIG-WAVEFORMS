"""Capture FPGA PN15 CPM-H at 1 Mbit/s and verify it with the Python detector."""
from pathlib import Path
import argparse, ctypes as C, json, os, subprocess, sys, time
import numpy as np
from scipy.ndimage import uniform_filter1d
from scipy.signal import correlate

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE / "reference"))
from cpm_demod import ALPHABET, branches, modulate, bit_errors

FS = 16_000_000
BIT_RATE = 1_000_000
SPS = 32                 # samples/dibit: two bits per CPM symbol
LO = 915_000_000
BW = 4_000_000
TX_GAIN_DB = -20
CAPTURE_FRAMES = 4_194_304
ANALYZE_DIBITS = 512
SYNC_DIBITS = 20_000
PUTTY = Path("C:/Program Files (x86)/PuTTY")
IIO_BIN = ROOT / "libiio-v0.26/Windows-VS-2022-x64"

def pn15_dibits(count, seed=0x7fff):
    def step(v):
        return (((v >> 14) ^ v) & 1) << 14 | (v >> 1)
    out = np.empty(count, dtype=np.uint8)
    state = seed
    for n in range(count):
        one = step(state)
        out[n] = ((state & 1) << 1) | (one & 1)
        state = step(one)
    return out

def trellis_state(dibits, count):
    """Exact detector state immediately before absolute symbol ``count``."""
    p = 0; b = 0; c = 0
    for n, dibit in enumerate(dibits[:count]):
        h = 4 + (n & 1)
        p, b, c = (p + h*c) % 32, int(ALPHABET[dibit]), b
    return p, b, c

def viterbi_from_state(received, initial_state, absolute_symbol, sps=SPS):
    y = np.asarray(received).reshape(-1, sps)
    metrics = {initial_state: 0.0}; survivors = []
    for n, observation in enumerate(y):
        updated = {}; links = {}
        for state, cost in metrics.items():
            templates, destinations = branches((absolute_symbol+n) & 1, state, sps)
            distances = np.sum(np.abs(templates-observation[None, :])**2, axis=1)
            for dibit in range(4):
                destination = destinations[dibit]
                proposed = cost + float(distances[dibit])
                if proposed < updated.get(destination, np.inf):
                    updated[destination] = proposed
                    links[destination] = state, dibit
        metrics = updated; survivors.append(links)
    state = min(metrics, key=metrics.get); cost = metrics[state]
    decoded = np.empty(len(y), dtype=np.uint8)
    for n in range(len(y)-1, -1, -1):
        state, decoded[n] = survivors[n][state]
    return decoded, cost

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host-key", required=True)
    p.add_argument("--uri", default="ip:192.168.2.1")
    args = p.parse_args()
    out = ROOT / "captures" / time.strftime("cpm-h-demod-%Y%m%d-%H%M%S")
    out.mkdir(parents=True)
    ssh_base = [str(PUTTY / "plink.exe"), "-ssh", "-batch", "-hostkey",
                args.host_key, "-pw", "analog", "root@192.168.2.1"]
    def ssh(command, timeout=20):
        r = subprocess.run([*ssh_base, command], capture_output=True, timeout=timeout)
        if r.returncode:
            raise RuntimeError(r.stderr.decode(errors="replace"))
        return r.stdout.decode(errors="replace").strip()
    def attr(dev, channel, key, value, output=True):
        cmd = [str(IIO_BIN / "iio_attr.exe"), "-u", args.uri, "-T", "5000",
               "-o" if output else "-i", "-c", dev, channel, key, str(value)]
        r = subprocess.run(cmd, capture_output=True, timeout=15)
        if r.returncode:
            raise RuntimeError(r.stderr.decode(errors="replace"))

    # Stop the persistent test stream, configure a coherent 16 MS/s loopback,
    # then allocate a zero-filled cyclic TX buffer to clock the post-FIR source.
    ssh("sh /tmp/cpm-h-control.sh stop || true")
    assert ssh("cat /sys/class/fpga_manager/fpga0/state") == "operating"
    for output in (True, False):
        attr("ad9361-phy", "voltage0", "sampling_frequency", FS, output)
        attr("ad9361-phy", "voltage0", "rf_bandwidth", BW, output)
    for ch in ("altvoltage0", "altvoltage1"):
        attr("ad9361-phy", ch, "frequency", LO)
    for ch in ("voltage0", "voltage1"):
        attr("ad9361-phy", ch, "gain_control_mode", "manual", False)
        attr("ad9361-phy", ch, "hardwaregain", 30, False)
    attr("ad9361-phy", "voltage0", "hardwaregain", -89.75)
    ssh("devmem 0x41210000 32 0; echo fdd > /sys/bus/iio/devices/iio:device0/ensm_mode")

    os.add_dll_directory(str(IIO_BIN))
    lib = C.CDLL(str(IIO_BIN / "libiio.dll")); ptr = C.c_void_p
    def api(name, ret, types):
        fn = getattr(lib, name); fn.restype = ret; fn.argtypes = types; return fn
    create = api("iio_create_context_from_uri", ptr, [C.c_char_p])
    destroy = api("iio_context_destroy", None, [ptr])
    find = api("iio_context_find_device", ptr, [ptr, C.c_char_p])
    channel = api("iio_device_find_channel", ptr, [ptr, C.c_char_p, C.c_bool])
    enable = api("iio_channel_enable", None, [ptr])
    create_buffer = api("iio_device_create_buffer", ptr, [ptr, C.c_size_t, C.c_bool])
    destroy_buffer = api("iio_buffer_destroy", None, [ptr])
    start = api("iio_buffer_start", ptr, [ptr]); end = api("iio_buffer_end", ptr, [ptr])
    push = api("iio_buffer_push", C.c_ssize_t, [ptr])
    ctx = txbuf = None
    try:
        ctx = create(args.uri.encode())
        if not ctx: raise RuntimeError("No Pluto IIO context")
        tx = find(ctx, b"cf-ad9361-dds-core-lpc")
        for n in range(4):
            ch = channel(tx, f"voltage{n}".encode(), True)
            if not ch: raise RuntimeError("Missing TX scan channel")
            enable(ch)
        txbuf = create_buffer(tx, 4096, True)
        if not txbuf: raise RuntimeError("Could not allocate cyclic TX buffer")
        C.memset(start(txbuf), 0, end(txbuf) - start(txbuf))
        if push(txbuf) < 0: raise RuntimeError("Could not start cyclic TX buffer")
        attr("ad9361-phy", "voltage0", "hardwaregain", TX_GAIN_DB)

        # A device-side delay makes the capture contain silence followed by the
        # exact reset/start of the deterministic FPGA PN15 CPM-H generator.
        delayed = subprocess.Popen([*ssh_base,
            "sleep 0.10; devmem 0x41210000 32 1"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        read = [str(IIO_BIN / "iio_readdev.exe"), "-u", args.uri, "-T", "5000",
                "-b", "32768", "-s", str(CAPTURE_FRAMES), "cf-ad9361-lpc",
                "voltage0", "voltage1", "voltage2", "voltage3"]
        r = subprocess.run(read, capture_output=True, timeout=20)
        delayed.communicate(timeout=5)
        if r.returncode or len(r.stdout) != CAPTURE_FRAMES * 8:
            raise RuntimeError(f"RX capture failed: bytes={len(r.stdout)} {r.stderr!r}")
        raw_path = out / "rx2-iq.bin"; raw_path.write_bytes(r.stdout)
    finally:
        try: ssh("devmem 0x41210000 32 0")
        except Exception: pass
        try: attr("ad9361-phy", "voltage0", "hardwaregain", -89.75)
        except Exception: pass
        if txbuf: destroy_buffer(txbuf)
        if ctx: destroy(ctx)

    frames = np.frombuffer(r.stdout, dtype="<i2").reshape(-1, 4)
    z = frames[:, 2].astype(float) + 1j * frames[:, 3].astype(float)
    power = uniform_filter1d(np.abs(z) ** 2, 256)
    baseline = np.median(power[:max(4096, len(power)//20)])
    high = np.percentile(power, 95)
    threshold = baseline + 0.30 * (high - baseline)
    hits = np.flatnonzero(power > threshold)
    if not len(hits): raise RuntimeError("No CPM-H energy transition found")
    coarse = int(hits[0])

    expected = pn15_dibits(SYNC_DIBITS)
    reference = modulate(expected, SPS)
    # USB buffering means the first host-visible high-energy sample need not be
    # the first FPGA sample. Match a stable received window anywhere within a
    # long deterministic PN15 reference, then advance to a symbol boundary.
    window_start = coarse + 10_000; train = 32_768
    observed = z[window_start:window_start+train]; observed -= np.mean(observed)
    best = None
    for conjugated in (False, True):
        candidate = np.conj(observed) if conjugated else observed
        corr = correlate(reference, candidate, mode="valid", method="fft")
        k = int(np.argmax(np.abs(corr)))
        segment = reference[k:k+train]
        score = abs(corr[k]) / (np.linalg.norm(segment)*np.linalg.norm(candidate)+1e-12)
        if best is None or score > best[0]: best = float(score), k, conjugated
    score, reference_sample, conjugated = best
    skip = (-reference_sample) % SPS
    start_pos = window_start + skip
    absolute_symbol = (reference_sample + skip) // SPS
    aligned = np.conj(z) if conjugated else z
    usable = min(ANALYZE_DIBITS*SPS, len(aligned)-start_pos,
                 (len(expected)-absolute_symbol)*SPS)
    usable -= usable % SPS
    aligned = aligned[start_pos:start_pos+usable]
    ref = reference[absolute_symbol*SPS:absolute_symbol*SPS+usable]
    phase = np.angle(np.vdot(ref, aligned))
    gain = np.vdot(ref, aligned*np.exp(-1j*phase)).real / np.vdot(ref, ref).real
    normalized = aligned*np.exp(-1j*phase) / max(abs(gain), 1e-12)
    initial = trellis_state(expected, absolute_symbol)
    decoded, path_cost = viterbi_from_state(normalized, initial, absolute_symbol)
    actual = expected[absolute_symbol:absolute_symbol+len(decoded)]
    errors = bit_errors(actual, decoded)
    result = {
        "sample_rate_hz": FS, "bit_rate_bps": BIT_RATE, "rf_bandwidth_hz": BW,
        "center_frequency_hz": LO, "tx_gain_db": TX_GAIN_DB,
        "captured_frames": CAPTURE_FRAMES,
        "energy_onset_sample": coarse, "aligned_start_sample": start_pos,
        "reference_sample": reference_sample,
        "absolute_symbol": absolute_symbol,
        "conjugated_iq": conjugated, "sync_correlation": score,
        "carrier_phase_rad": float(phase), "complex_gain": float(gain),
        "decoded_dibits": int(len(decoded)), "decoded_bits": int(2*len(decoded)),
        "bit_errors": errors, "ber": errors/(2*len(decoded)),
        "viterbi_cost_per_sample": float(path_cost/usable),
    }
    (out / "result.json").write_text(json.dumps(result, indent=2))
    np.save(out / "decoded_dibits.npy", decoded)
    print(json.dumps(result, indent=2)); print(f"Saved {out}")
    if errors: raise SystemExit(2)

if __name__ == "__main__": main()
