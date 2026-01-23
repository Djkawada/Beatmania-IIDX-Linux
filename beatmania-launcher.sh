#!/bin/bash

# Path to the game directory
GAME_DIR="/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500"

# Check if directory exists
if [ ! -d "$GAME_DIR" ]; then
    echo "Error: Game directory not found at $GAME_DIR"
    exit 1
fi

cd "$GAME_DIR"

# Kill any existing instances first
killall -9 asphyxia-core-x64.exe spice64.exe 2>/dev/null
killall -9 speech-dispatcher 2>/dev/null # Fix #5: Remove accessibility interference

# Fix #2: Adjust Pipewire Quantum for motherboard audio stability
# Even with pure ALSA, setting the hardware rate/quantum helps.
if command -v pw-metadata >/dev/null 2>&1; then
    echo "Setting Pipewire quantum to 1024..."
    pw-metadata -n settings 0 clock.force-quantum 1024
    pw-metadata -n settings 0 clock.force-rate 44100
fi

# Start Asphyxia server in the background
echo "Starting Asphyxia Core..."
export NODE_SKIP_PLATFORM_CHECK=1
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!

# Give it a moment to initialize
sleep 5

# Start the game
# Using DirectSound over pure ALSA driver (Wine registry updated)
echo "Starting Beatmania IIDX..."
export DXVK_HUD=1
# Adding a small latency buffer to smooth out remaining crackles
export PULSE_LATENCY_MSEC=60
wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound

# Cleanup: Kill Asphyxia when the game exits
if command -v pw-metadata >/dev/null 2>&1; then
    pw-metadata -n settings 0 clock.force-quantum 0
    pw-metadata -n settings 0 clock.force-rate 0
fi
kill $ASPHYXIA_PID
if command -v pw-metadata >/dev/null 2>&1; then
    echo "Resetting Pipewire settings..."
    pw-metadata -n settings 0 clock.force-quantum 0
    pw-metadata -n settings 0 clock.force-rate 0
fi

# Cleanup: Kill Asphyxia when the game exits


# Cleanup: Kill Asphyxia when the game exits
echo "Game exited. Stopping Asphyxia..."
kill $ASPHYXIA_PID