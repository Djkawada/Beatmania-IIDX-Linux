#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SOUND_BRIDGE_BIN="$SCRIPT_DIR/iidx-sound-bridge/target/release/iidx-sound-bridge"

# Color Codes
CYAN='\033[1;36m'
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}===================================================${NC}"
echo -e "${PINK}       BEATMANIA IIDX HYPRLAND LAUNCHER            ${NC}"
echo -e "${CYAN}===================================================${NC}"

GAME_DIR=$(jq -r '.game_dir' "$CONFIG_FILE")
ASPHYXIA_EXE=$(jq -r '.asphyxia_exe // "./asphyxia-core"' "$CONFIG_FILE")
SPICE_EXE=$(jq -r '.spice_exe' "$CONFIG_FILE")
WINEPREFIX=$(jq -r '.wine_prefix' "$CONFIG_FILE")
WINE_BIN=$(jq -r '.wine_binary' "$CONFIG_FILE")
CARD_ID=$(jq -r '.card_id' "$CONFIG_FILE")
ASPHYXIA_PORT=$(jq -r '.asphyxia_port // 8083' "$CONFIG_FILE")
NETWORK_URL=$(jq -r '.network_url // "http://127.0.0.1:8083"' "$CONFIG_FILE")

WINDOWED=$(jq -r '.display.windowed' "$CONFIG_FILE")
PW_LATENCY=$(jq -r '.sound.pipewire_latency // "256/44100"' "$CONFIG_FILE")
WASAPI_MODE=$(jq -r '.sound.wasapi_mode // "shared"' "$CONFIG_FILE")
SAMPLE_RATE=$(jq -r '.sound.sample_rate // 44100' "$CONFIG_FILE")
BUFFER_QUANTUM=$(jq -r '.sound.buffer_quantum // 256' "$CONFIG_FILE")

if [ -z "$WINE_BIN" ] || [ "$WINE_BIN" = "null" ] || [ ! -f "$WINE_BIN" ]; then
    WINE_BIN="wine"
fi

# Environment configuration for DirectX 9 (DXVK), PipeWire audio & low-jitter threading
export WINEPREFIX
export PIPEWIRE_LATENCY="$PW_LATENCY"
export PIPEWIRE_RATE="1/$SAMPLE_RATE"
export WINEFSYNC=1
export WINEESYNC=1
export WINE_RT_PRIO=1
export STAGING_AUDIO_DURATION=3000
export WINEDLLOVERRIDES="d3d9=n"
export WINEDEBUG="-all"
export __compat_layer=RunAsInvoker

# MangoHud configuration: lightweight top-right HUD
export MANGOHUD=1
export MANGOHUD_CONFIG="position=top-right,fps,frametime=0,no_display=0,font_size=18,background_alpha=0.25,round_corners=6"

# Step 1: Ensure Rust sound bridge binary exists
if [ ! -f "$SOUND_BRIDGE_BIN" ]; then
    echo -e "${YELLOW}[*] Building Rust Sound Bridge (iidx-sound-bridge)...${NC}"
    cd "$SCRIPT_DIR/iidx-sound-bridge"
    cargo build --release
    cd "$SCRIPT_DIR"
fi

# Step 2: Start Rust Sound Bridge
if ! pgrep -f "iidx-sound-bridge" >/dev/null 2>&1; then
    echo -e "${GREEN}[+] Starting Rust Audio Latency & Rate Bridge (${SAMPLE_RATE}Hz)...${NC}"
    setsid "$SOUND_BRIDGE_BIN" --rate "$SAMPLE_RATE" --buffer "$BUFFER_QUANTUM" > "$SCRIPT_DIR/sound_bridge.log" 2>&1 &
    SOUND_BRIDGE_PID=$!
    disown $SOUND_BRIDGE_PID 2>/dev/null || true
    sleep 1
fi

cleanup() {
    echo -e "\n${YELLOW}[*] Session ended. Cleaning up background services...${NC}"
    if [ -n "$SOUND_BRIDGE_PID" ] && kill -0 $SOUND_BRIDGE_PID 2>/dev/null; then
        kill -SIGINT $SOUND_BRIDGE_PID 2>/dev/null || true
    fi
    pw-metadata -n settings 0 clock.force-rate 0 2>/dev/null || true
    echo -e "${GREEN}[+] Cleanup complete.${NC}"
}
trap cleanup INT TERM EXIT

# Step 3: Start Asphyxia Core directly on port 8083
pkill -f "iidx-ea-proxy" 2>/dev/null || true
ASPHYXIA_PORT=8083
chmod +x "$GAME_DIR/asphyxia-core" 2>/dev/null || true

if ! curl -s "http://127.0.0.1:$ASPHYXIA_PORT/" >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Starting Native Asphyxia Core on port $ASPHYXIA_PORT...${NC}"
    cd "$GAME_DIR"
    if [[ "$ASPHYXIA_EXE" == *.exe ]]; then
        setsid "$WINE_BIN" "$ASPHYXIA_EXE" -p "$ASPHYXIA_PORT" -b 0.0.0.0 -pa 127.0.0.1 --dev > "$SCRIPT_DIR/asphyxia.log" 2>&1 &
    else
        setsid ./asphyxia-core -p "$ASPHYXIA_PORT" -b 0.0.0.0 -pa 127.0.0.1 --dev > "$SCRIPT_DIR/asphyxia.log" 2>&1 &
    fi
    ASPHYXIA_PID=$!
    disown $ASPHYXIA_PID 2>/dev/null || true

    COUNT=0
    while ! curl -s "http://127.0.0.1:$ASPHYXIA_PORT/" >/dev/null 2>&1; do
        sleep 0.5
        COUNT=$((COUNT + 1))
        if [ $COUNT -ge 30 ]; then
            echo -e "${RED}[-] Timeout waiting for Asphyxia on port $ASPHYXIA_PORT.${NC}"
            exit 1
        fi
    done
fi
echo -e "${GREEN}[+] Asphyxia Core active on http://127.0.0.1:$ASPHYXIA_PORT.${NC}"

# Step 4: Launch Beatmania IIDX
WINDOW_FLAG=""
if [ "$WINDOWED" = "true" ]; then
    WINDOW_FLAG="-w"
fi

SOUND_FLAG="-wasapishared -lowlatencysharedaudio"
if [ "$WASAPI_MODE" = "exclusive" ]; then
    SOUND_FLAG="-wasapiexclusive"
fi

DEVICE_TYPE=$(jq -r '.sound.device_type // "wasapi"' "$CONFIG_FILE")

cd "$GAME_DIR"
if [ "$DEVICE_TYPE" = "asio" ]; then
    echo -e "${GREEN}[+] Launching Beatmania IIDX with WineASIO + pw-jack (< 2ms Keysound Latency)...${NC}"
    pw-jack mangohud "$WINE_BIN" "$SPICE_EXE" \
        -cmdoverride \
        -url "$NETWORK_URL" \
        $WINDOW_FLAG \
        -iidx \
        -nolauncher \
        -norelaunch \
        -noadmin \
        -icmphook \
        -iidxsounddevice asio \
        -iidxasio "WineASIO"
else
    echo -e "${GREEN}[+] Launching Beatmania IIDX ($WINE_BIN) with MangoHud...${NC}"
    mangohud "$WINE_BIN" "$SPICE_EXE" \
        -cmdoverride \
        -url "$NETWORK_URL" \
        $WINDOW_FLAG \
        -iidx \
        -nolauncher \
        -norelaunch \
        -noadmin \
        -icmphook \
        -iidxsounddevice wasapi \
        $SOUND_FLAG
fi

echo -e "${YELLOW}[*] Game closed naturally.${NC}"
