#!/bin/bash
set -e
# Use HOME variable for portability
GAME_DIR="$HOME/Games/Beatmania IIDX/Beatmania 2023090500"

if [ ! -d "$GAME_DIR" ]; then
  echo "Error: Game directory not found: $GAME_DIR"
  exit 1
fi
cd "$GAME_DIR"

# Graceful cleanup
pkill -f asphyxia-core-x64.exe 2>/dev/null || true
pkill -f spice64.exe 2>/dev/null || true
pkill -f speech-dispatcher 2>/dev/null || true

# Exports
export NODE_SKIP_PLATFORM_CHECK=1
export WINEESYNC=1            # Enable eventfd-based synchronization (lower latency)
unset DXVK_HUD                # Disable HUD to reduce GPU overhead

# 1. Pipewire Optimization (Hardware Level)
# Reverting to 48kHz ALSA logic (Hardware Native)
if command -v pw-metadata >/dev/null 2>&1; then
    echo "Configuring Audio Hardware (Pipewire)..."
    pw-metadata -n settings 0 clock.force-rate 48000
    pw-metadata -n settings 0 clock.force-quantum 512
fi

# Start Asphyxia (Background)
echo "Starting Asphyxia Core..."
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!
sleep 5

# Using DirectSound over ALSA (maps via Registry)
export PIPEWIRE_LATENCY="512/48000"
RUN_CMD="wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound"

# Realtime Priority (chrt)
# Execute directly without eval to keep PID tracking simple
echo "Launching game..."
if command -v chrt >/dev/null 2>&1; then
    chrt -f 70 $RUN_CMD &
else
    $RUN_CMD &
fi
WINE_PID=$!

echo "Game running with PID $WINE_PID"
wait $WINE_PID

echo "Game exited. Cleaning up..."
kill $ASPHYXIA_PID 2>/dev/null || true
pkill -f spice64.exe 2>/dev/null || true
exit 0
