#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root (for example: sudo ./build.sh)." >&2
    exit 1
fi

lb config \
    --distribution bookworm \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-indices false \
    --apt-recommends false \
    --debootstrap-options "--variant=minbase" \
    --bootappend-live "boot=live components quiet splash persistence"

lb build
