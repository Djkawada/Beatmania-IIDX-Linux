#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

GAME_DIR=$(jq -r '.game_dir' "$CONFIG_FILE")
SPICE_EXE=$(jq -r '.spice_exe' "$CONFIG_FILE")
WINEPREFIX=$(jq -r '.wine_prefix' "$CONFIG_FILE")
WINE_BIN=$(jq -r '.wine_binary' "$CONFIG_FILE")
CARD_ID=$(jq -r '.card_id' "$CONFIG_FILE")
NETWORK_URL=$(jq -r '.network_url' "$CONFIG_FILE")

WINDOWED=$(jq -r '.display.windowed' "$CONFIG_FILE")
WASAPI_MODE=$(jq -r '.sound.wasapi_mode' "$CONFIG_FILE")

if [ -z "$WINE_BIN" ] || [ "$WINE_BIN" = "null" ] || [ ! -f "$WINE_BIN" ]; then
    WINE_BIN="wine"
fi

export WINEPREFIX
export PIPEWIRE_LATENCY="$PW_LATENCY"
export PIPEWIRE_RATE="1/$SAMPLE_RATE"
export WINEFSYNC=1
export WINEESYNC=1
export WINE_RT_PRIO=1
export STAGING_AUDIO_DURATION=10000
export WINEDLLOVERRIDES="d3d9=n;mmdevapi=n,b;dsound=n,b;mfplat=b;mf=b;quartz=b;devenum=b;wmadmod=b;wmvdecod=b"
export WINEDEBUG="-all"
export __compat_layer=RunAsInvoker

WINDOW_FLAG=""
if [ "$WINDOWED" = "true" ]; then
    WINDOW_FLAG="-w"
fi

SOUND_FLAG="-wasapishared"
if [ "$WASAPI_MODE" = "exclusive" ]; then
    SOUND_FLAG="-wasapiexclusive"
fi

cd "$GAME_DIR"
echo "[+] Launching Beatmania IIDX with GE-Proton10-34..."
"$WINE_BIN" "$SPICE_EXE" \
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
