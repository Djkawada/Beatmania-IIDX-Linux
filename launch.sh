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

# Environment configuration for DirectX 9 (DXVK) and PipeWire audio
export WINEPREFIX
export PIPEWIRE_LATENCY="$PW_LATENCY"
export PIPEWIRE_RATE="1/$SAMPLE_RATE"
export WINEDLLOVERRIDES="d3d9=n;mmdevapi=n,b;dsound=n,b;mfplat=b;mf=b;quartz=b;devenum=b;wmadmod=b;wmvdecod=b"
export WINEDEBUG="-all"
export __compat_layer=RunAsInvoker

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
trap cleanup INT TERM

# Step 3: Check / Start Native Asphyxia Core (8084) & Region Fixer Proxy (8083)
PROXY_BIN="$SCRIPT_DIR/iidx-ea-proxy/target/release/iidx-ea-proxy"
PROXY_PORT=8083
ASPHYXIA_PORT=8084

if [ ! -f "$PROXY_BIN" ] || [ "$SCRIPT_DIR/iidx-ea-proxy/src/main.rs" -nt "$PROXY_BIN" ]; then
    echo -e "${YELLOW}[*] Building / Updating Rust EA Proxy (iidx-ea-proxy)...${NC}"
    cd "$SCRIPT_DIR/iidx-ea-proxy"
    cargo build --release
    cd "$SCRIPT_DIR"
fi

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

pkill -f "iidx-ea-proxy" 2>/dev/null || true
sleep 0.2
echo -e "${YELLOW}[*] Starting XRPC Japan Region Fixer Proxy (port $PROXY_PORT -> $ASPHYXIA_PORT)...${NC}"
setsid "$PROXY_BIN" --port "$PROXY_PORT" --target-port "$ASPHYXIA_PORT" > "$SCRIPT_DIR/proxy.log" 2>&1 &
PROXY_PID=$!
disown $PROXY_PID 2>/dev/null || true

COUNT=0
while ! curl -s "http://127.0.0.1:$PROXY_PORT/" >/dev/null 2>&1; do
    sleep 0.3
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge 30 ]; then
        echo -e "${RED}[-] Timeout waiting for Proxy on port $PROXY_PORT.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}[+] e-Amusement Card Services active on http://127.0.0.1:$PROXY_PORT (Region: JP).${NC}"

# Step 4: Launch Beatmania IIDX
WINDOW_FLAG=""
if [ "$WINDOWED" = "true" ]; then
    WINDOW_FLAG="-w"
fi

SOUND_FLAG="-wasapishared"
if [ "$WASAPI_MODE" = "exclusive" ]; then
    SOUND_FLAG="-wasapiexclusive"
fi

cd "$GAME_DIR"
echo -e "${GREEN}[+] Launching Beatmania IIDX ($WINE_BIN)...${NC}"
"$WINE_BIN" "$SPICE_EXE" \
    -cmdoverride \
    -ea \
    -url "$NETWORK_URL" \
    $WINDOW_FLAG \
    -iidx \
    -nolauncher \
    -norelaunch \
    -noadmin \
    -iidxsounddevice wasapi \
    $SOUND_FLAG

echo -e "${YELLOW}[*] Game closed naturally.${NC}"
cleanup
