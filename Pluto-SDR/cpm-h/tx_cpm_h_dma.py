"""Continuously stream a deterministic PN15 ARTM CPM-H waveform to Pluto TX1.

This is the stimulus source for the FPGA receiver loopback test.  It uses the
normal Pluto DMA transmit path; the custom receiver and PN15 score remain in
FPGA fabric.  Stop with Ctrl-C.
"""
from pathlib import Path
import argparse
import ctypes as C
import os
import sys
import time

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE / "reference"))
from cpm_demod import modulate

IIO_BIN = ROOT / "libiio-v0.26/Windows-VS-2022-x64"


def pn15_dibits(count: int, seed: int = 0x7FFF) -> np.ndarray:
    def step(value: int) -> int:
        return ((((value >> 14) ^ value) & 1) << 14) | (value >> 1)

    result = np.empty(count, dtype=np.uint8)
    state = seed
    for index in range(count):
        second = step(state)
        result[index] = ((state & 1) << 1) | (second & 1)
        state = step(second)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", default="ip:192.168.2.1")
    parser.add_argument("--frequency", type=int, default=915_000_000)
    parser.add_argument("--sample-rate", type=int, default=16_000_000)
    parser.add_argument("--rf-bandwidth", type=int, default=4_000_000)
    parser.add_argument("--tx-gain", type=float, default=-30.0)
    parser.add_argument("--dibits", type=int, default=4096)
    parser.add_argument("--samples-per-dibit", type=int, default=32)
    parser.add_argument("--phase-degrees", type=float, default=0.0)
    parser.add_argument("--conjugate", action="store_true")
    args = parser.parse_args()

    samples_per_dibit = args.samples_per_dibit
    if samples_per_dibit < 1:
        raise SystemExit("samples per dibit must be positive")
    waveform = modulate(pn15_dibits(args.dibits), samples_per_dibit)
    if args.conjugate:
        waveform = np.conj(waveform)
    waveform *= np.exp(1j * np.deg2rad(args.phase_degrees))
    scale = 0.70 * 32767
    frames = np.zeros((len(waveform), 4), dtype="<i2")
    frames[:, 0] = np.rint(scale * waveform.real).astype(np.int16)
    frames[:, 1] = np.rint(scale * waveform.imag).astype(np.int16)

    os.add_dll_directory(str(IIO_BIN))
    lib = C.CDLL(str(IIO_BIN / "libiio.dll"))
    pointer = C.c_void_p

    def api(name, result, arguments):
        fn = getattr(lib, name)
        fn.restype = result
        fn.argtypes = arguments
        return fn

    create_context = api("iio_create_context_from_uri", pointer, [C.c_char_p])
    destroy_context = api("iio_context_destroy", None, [pointer])
    find_device = api("iio_context_find_device", pointer, [pointer, C.c_char_p])
    find_channel = api("iio_device_find_channel", pointer, [pointer, C.c_char_p, C.c_bool])
    enable_channel = api("iio_channel_enable", None, [pointer])
    write_longlong = api("iio_channel_attr_write_longlong", C.c_ssize_t,
                         [pointer, C.c_char_p, C.c_longlong])
    write_double = api("iio_channel_attr_write_double", C.c_ssize_t,
                       [pointer, C.c_char_p, C.c_double])
    create_buffer = api("iio_device_create_buffer", pointer, [pointer, C.c_size_t, C.c_bool])
    destroy_buffer = api("iio_buffer_destroy", None, [pointer])
    buffer_start = api("iio_buffer_start", pointer, [pointer])
    buffer_end = api("iio_buffer_end", pointer, [pointer])
    buffer_push = api("iio_buffer_push", C.c_ssize_t, [pointer])

    context = buffer = None
    try:
        context = create_context(args.uri.encode())
        if not context:
            raise RuntimeError(f"could not connect to {args.uri}")
        phy = find_device(context, b"ad9361-phy")
        tx = find_device(context, b"cf-ad9361-dds-core-lpc")
        if not phy or not tx:
            raise RuntimeError("Pluto PHY or TX DMA device is missing")

        tx_phy = find_channel(phy, b"voltage0", True)
        tx_lo = find_channel(phy, b"altvoltage1", True)
        for attribute, value in ((b"sampling_frequency", args.sample_rate),
                                 (b"rf_bandwidth", args.rf_bandwidth)):
            if write_longlong(tx_phy, attribute, value) < 0:
                raise RuntimeError(f"could not set {attribute.decode()}")
        if write_longlong(tx_lo, b"frequency", args.frequency) < 0:
            raise RuntimeError("could not set TX LO")
        if write_double(tx_phy, b"hardwaregain", args.tx_gain) < 0:
            raise RuntimeError("could not set TX gain")

        for index in range(4):
            channel = find_channel(tx, f"voltage{index}".encode(), True)
            if not channel:
                raise RuntimeError(f"TX scan channel voltage{index} is missing")
            enable_channel(channel)

        buffer = create_buffer(tx, len(frames), True)
        if not buffer:
            raise RuntimeError("could not allocate cyclic TX buffer")
        start = buffer_start(buffer)
        size = buffer_end(buffer) - start
        payload = frames.tobytes()
        if size != len(payload):
            raise RuntimeError(f"DMA layout mismatch: buffer={size}, waveform={len(payload)}")
        C.memmove(start, payload, len(payload))
        if buffer_push(buffer) < 0:
            raise RuntimeError("could not start cyclic TX DMA")

        bit_rate = args.sample_rate * 2 // samples_per_dibit
        print(f"CPM-H PN15 transmitting on TX1: {args.frequency/1e6:.6f} MHz, "
              f"{bit_rate/1e6:.3f} Mbit/s, {args.sample_rate/1e6:.3f} MS/s, "
              f"gain {args.tx_gain:.2f} dB, phase {args.phase_degrees:.2f} deg, "
              f"conjugate={args.conjugate}", flush=True)
        print("Press Ctrl-C to stop and release the cyclic DMA buffer.", flush=True)
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nTX stopped")
    finally:
        if buffer:
            destroy_buffer(buffer)
        if context:
            destroy_context(context)


if __name__ == "__main__":
    main()
