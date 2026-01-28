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
    pw-metadata -n settings 0 clock.force-quantum 256
fi

# Start Asphyxia (Background)
echo "Starting Asphyxia Core..."
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!
sleep 5

# Using DirectSound over ALSA (maps via Registry)
export PIPEWIRE_LATENCY="256/48000"
RUN_CMD="wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound"

# Realtime Priority (chrt)
# Requires user limits configuration, but harmless if it fails
if command -v chrt >/dev/null 2>&1; then
  echo "Attempting launch with Realtime Priority (FIFO 70)..."
  # Try to run with high priority. If chrt fails (perm denied), fallback to normal run.
  if ! chrt -f 70 sh -c "$RUN_CMD" &>/dev/null; then
      echo "  -> RT priority failed (check limits.conf), falling back to normal priority."
      eval "$RUN_CMD" &
  else
      eval "chrt -f 70 $RUN_CMD" &
  fi
else
  eval "$RUN_CMD" &
fi
WINE_PID=$!

echo "Game running with PID $WINE_PID"
wait $WINE_PID || true

echo "Game exited. Cleaning up..."
kill $ASPHYXIA_PID 2>/dev/null || true
