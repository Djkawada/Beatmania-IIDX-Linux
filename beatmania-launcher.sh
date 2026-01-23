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

# 1. Pipewire Optimization (Hardware Level)
# Force 44.1kHz and 1024 quantum (Standard High Quality)
if command -v pw-metadata >/dev/null 2>&1; then
    echo "Configuring Audio Hardware (Pipewire)..."
    pw-metadata -n settings 0 clock.force-rate 44100
    pw-metadata -n settings 0 clock.force-quantum 1024
fi

# 2. Start Asphyxia (Network)
echo "Starting Asphyxia Core..."
# Fix for Node.js platform check on Wine
export NODE_SKIP_PLATFORM_CHECK=1
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!

sleep 5

# 3. Start Game
# -iidxsounddevice wasapi: Using PulseAudio's WASAPI emulation (High Quality Resampling Enabled)
echo "Starting Beatmania IIDX..."
export DXVK_HUD=1
export PULSE_LATENCY_MSEC=60
wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice wasapi

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