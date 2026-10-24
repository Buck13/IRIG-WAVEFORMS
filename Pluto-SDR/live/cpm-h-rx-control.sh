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
    value=$(devmem 0x41220008 32)
    number=$((value))
    printf 'raw=%s done=%d errors=%d checked=%d decoded=%d valid=%d dibit=%d overflow=%d dropped=%d busy=%d aligned=%d\n' \
      "$value" $(((number >> 31) & 1)) $(((number >> 24) & 127)) \
      $(((number >> 17) & 127)) $(((number >> 10) & 127)) \
      $(((number >> 6) & 1)) $(((number >> 4) & 3)) \
      $(((number >> 3) & 1)) $(((number >> 2) & 1)) \
      $(((number >> 1) & 1)) $((number & 1))
    ;;
  auto)
    best_errors=65
    best_offset=0
    best_epoch=0
    for epoch in 0 1 2 3; do
      offset=0
      while [ "$offset" -lt 32 ]; do
        control=$((1 | 2 | ((offset & 31) << 2) | ((epoch & 3) << 7)))
        devmem "$base" 32 "$control" >/dev/null
        devmem "$base" 32 $((control & ~2)) >/dev/null
        polls=0
        while :; do
          value=$(devmem 0x41220008 32)
          number=$((value))
          if [ $(((number >> 31) & 1)) -eq 1 ]; then break; fi
          polls=$((polls + 1))
          if [ "$polls" -ge 2000 ]; then break; fi
          usleep 1000
        done
        errors=$(((number >> 24) & 127))
        done=$(((number >> 31) & 1))
        if [ "$done" -eq 1 ] && [ "$errors" -lt "$best_errors" ]; then
          best_errors=$errors
          best_offset=$offset
          best_epoch=$epoch
        fi
        offset=$((offset + 1))
      done
    done
    if [ "$best_errors" -gt 64 ]; then
      echo 'automatic acquisition failed: no hypothesis completed' >&2
      exit 1
    fi
    control=$((1 | 2 | ((best_offset & 31) << 2) | ((best_epoch & 3) << 7)))
    devmem "$base" 32 "$control" >/dev/null
    devmem "$base" 32 $((control & ~2)) >/dev/null
    printf 'selected timing-offset=%d epoch=%d PN15-errors=%d/64\n' \
      "$best_offset" "$best_epoch" "$best_errors"
    ;;
  *)
    echo "usage: $0 {start [timing-offset 0..31] [epoch 0..3]|auto|restart|stop|status}" >&2
    exit 2
    ;;
esac
