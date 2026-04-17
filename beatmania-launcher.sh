#!/bin/bash
GAME_DIR="$HOME/Games/Beatmania IIDX/Beatmania 2023090500"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARD_ID=$(cat "$SCRIPT_DIR/card.txt" 2>/dev/null || echo "00000000000000000000")

# 1. Cleanup
pkill -9 -f asphyxia-core-x64.exe 2>/dev/null || true
pkill -9 -f spice64.exe 2>/dev/null || true
pkill -9 -f audio_bridge_server 2>/dev/null || true

# 2. Start Native Rust Server
echo "[+] Starting Native Audio Server..."
"$SCRIPT_DIR/audio_bridge_server/target/release/audio_bridge_server" &
SERVER_PID=$!

# 3. Start Asphyxia
echo "[+] Starting Asphyxia Core..."
cd "$GAME_DIR"
wine asphyxia-core-x64.exe > /dev/null 2>&1 &
ASPHYXIA_PID=$!
sleep 5

# 4. Copy Plugin DLL
cp "$SCRIPT_DIR/asio_bridge/target/x86_64-pc-windows-gnu/release/asio_bridge.dll" "$GAME_DIR/modules/audio_bridge.dll"

# 5. Launch Game
# We use standard arguments and avoid -plugin if it causes issues.
# Instead, we will name the DLL 'dsound.dll' to force loading as a proxy.
cp "$GAME_DIR/modules/audio_bridge.dll" "$GAME_DIR/dsound.dll"

echo "[+] Launching Game with Rust Audio Proxy..."
# Force Wine to use our local dsound.dll (the Rust one)
export WINEDLLOVERRIDES="dsound=n,b"

wine spice64.exe -url http://localhost:8083 -card0 $CARD_ID -iidx -w -iidxsounddevice dsound

# 6. Cleanup
kill $ASPHYXIA_PID $SERVER_PID 2>/dev/null || true
rm -f "$GAME_DIR/dsound.dll"
echo "Game exited."
