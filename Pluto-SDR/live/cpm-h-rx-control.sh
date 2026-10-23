#!/bin/sh
set -eu

base=0x41220000
command=${1:-status}

case "$command" in
  start)
    offset=${2:-0}
    epoch=${3:-0}
    control=$((1 | ((offset & 31) << 2) | ((epoch & 3) << 7)))
    devmem "$base" 32 "$control"
    ;;
  restart)
    current=$(devmem "$base" 32)
    devmem "$base" 32 $((current | 2))
    devmem "$base" 32 $((current & ~2))
    ;;
  stop)
    devmem "$base" 32 0
    ;;
  status)
    devmem 0x41220008 32
    ;;
  *)
    echo "usage: $0 {start [timing-offset 0..31] [epoch 0..3]|restart|stop|status}" >&2
    exit 2
    ;;
esac
