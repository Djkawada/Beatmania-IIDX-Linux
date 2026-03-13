#!/bin/bash
set -e
# Use HOME variable for portability
GAME_DIR="$HOME/Games/Beatmania IIDX/Beatmania 2023090500"

if [ ! -d "$GAME_DIR" ]; then
  echo "Error: Game directory not found: $GAME_DIR"
  exit 1
fi

# Load Card ID from file (Keep this file private!)
# Moving to script directory first to find card.txt
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/card.txt" ]; then
    CARD_ID=$(cat "$SCRIPT_DIR/card.txt")
else
    CARD_ID="00000000000000000000"
fi

cd "$GAME_DIR"

# Graceful cleanup
pkill -f asphyxia-core-x64.exe 2>/dev/null || true
pkill -f spice64.exe 2>/dev/null || true
pkill -f speech-dispatcher 2>/dev/null || true

# Exports
export NODE_SKIP_PLATFORM_CHECK=1
export WINEESYNC=1            # Enable eventfd-based synchronization
export WINEPULSE_FAST_POLLING=1 # Critical for rhythm games on Wine
unset DXVK_HUD

# Exports
export NODE_SKIP_PLATFORM_CHECK=1
export WINEESYNC=1            # Enable eventfd-based synchronization
export WINEPULSE_FAST_POLLING=1 # Critical for rhythm games on Wine
# FORCE STEREO & DIRECT SINK: Ignores HDMI and forces 2 channels at the Pulse layer
export PULSE_SINK="alsa_output.pci-0000_0c_00.4.analog-stereo"
export PULSE_CHANNELS=2
export WINE_PULSE_CHANNELS=2
export PULSE_LATENCY_MSEC=60
unset DXVK_HUD

# 1. Pipewire Optimization (Hardware Level)
if command -v pw-metadata >/dev/null 2>&1; then
    echo "Locking Pipewire to 44.1kHz Stereo..."
    pw-metadata -n settings 0 clock.force-rate 44100
    pw-metadata -n settings 0 clock.force-quantum 512
fi

# Start Asphyxia (Background)
echo "Starting Asphyxia Core..."
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!
sleep 5

# Using Linux-optimized Spice binaries with WASAPI (Shared)
# Locked to 2 channels via PULSE_CHANNELS exports.
echo "Using Linux-optimized Spice binaries (Pulse Stereo Force)..."
RUN_CMD="wine spice64.exe -url http://localhost:8083 -card0 $CARD_ID -iidx -w -iidxsounddevice wasapi"

# Realtime Priority (chrt)
# We test permission with a simple 'true' command instead of launching the whole game.
if command -v chrt >/dev/null 2>&1 && chrt -f 1 true 2>/dev/null; then
    echo "Launching with Realtime Priority (FIFO 70)..."
    chrt -f 70 $RUN_CMD &
else
    echo "Launching with Normal Priority (chrt not available or permission denied)..."
    $RUN_CMD &
fi
WINE_PID=$!

echo "Game running with PID $WINE_PID"
wait $WINE_PID || true

echo "Game exited. Cleaning up..."
kill $ASPHYXIA_PID 2>/dev/null || true
pkill -f spice64.exe 2>/dev/null || true
exit 0
