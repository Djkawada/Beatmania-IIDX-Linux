#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

GAME_DIR=$(jq -r '.game_dir' "$CONFIG_FILE")
ASPHYXIA_EXE=$(jq -r '.asphyxia_exe // "./asphyxia-core"' "$CONFIG_FILE")
WINEPREFIX=$(jq -r '.wine_prefix' "$CONFIG_FILE")
WINE_BIN=$(jq -r '.wine_binary' "$CONFIG_FILE")
ASPHYXIA_PORT=$(jq -r '.asphyxia_port // 8083' "$CONFIG_FILE")

PROXY_BIN="$SCRIPT_DIR/iidx-ea-proxy/target/release/iidx-ea-proxy"
PROXY_PORT=8083

if [ -z "$WINE_BIN" ] || [ "$WINE_BIN" = "null" ] || [ ! -f "$WINE_BIN" ]; then
    WINE_BIN="wine"
fi

export WINEPREFIX

echo "==================================================="
echo "   BEATMANIA IIDX ASPHYXIA & REGION PROXY SERVER   "
echo "==================================================="

# Build proxy if missing
if [ ! -f "$PROXY_BIN" ]; then
    echo "[*] Compiling iidx-ea-proxy..."
    cd "$SCRIPT_DIR/iidx-ea-proxy"
    cargo build --release
    cd "$SCRIPT_DIR"
fi

# 1. Start Asphyxia Core on port 8084
if ! curl -s "http://127.0.0.1:$ASPHYXIA_PORT/" >/dev/null 2>&1; then
    echo "[+] Booting Native Asphyxia Core on port $ASPHYXIA_PORT..."
    cd "$GAME_DIR"
    chmod +x ./asphyxia-core 2>/dev/null || true
    if [[ "$ASPHYXIA_EXE" == *.exe ]]; then
        setsid "$WINE_BIN" "$ASPHYXIA_EXE" -p "$ASPHYXIA_PORT" -b 0.0.0.0 -pa 127.0.0.1 --dev > "$SCRIPT_DIR/asphyxia.log" 2>&1 &
    else
        setsid ./asphyxia-core -p "$ASPHYXIA_PORT" -b 0.0.0.0 -pa 127.0.0.1 --dev > "$SCRIPT_DIR/asphyxia.log" 2>&1 &
    fi
    ASPHYXIA_PID=$!
    sleep 1
else
    echo "[+] Asphyxia Core is already active on port $ASPHYXIA_PORT."
fi

# 2. Start XRPC Japan Region Fixer Proxy on port 8083
if ! curl -s "http://127.0.0.1:$PROXY_PORT/" >/dev/null 2>&1; then
    echo "[+] Booting Rust XRPC Region Fixer Proxy (port $PROXY_PORT -> $ASPHYXIA_PORT)..."
    setsid "$PROXY_BIN" --port "$PROXY_PORT" --target-port "$ASPHYXIA_PORT" > "$SCRIPT_DIR/proxy.log" 2>&1 &
    PROXY_PID=$!
    sleep 1
else
    echo "[+] Region Fixer Proxy is already active on port $PROXY_PORT."
fi

echo "[+] All e-Amusement card services active on http://127.0.0.1:$PROXY_PORT (Region: JP)."

cleanup() {
    echo "[*] Stopping servers..."
    [ -n "$PROXY_PID" ] && kill $PROXY_PID 2>/dev/null || true
    [ -n "$ASPHYXIA_PID" ] && kill $ASPHYXIA_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait
