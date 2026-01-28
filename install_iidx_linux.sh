#!/bin/bash
set -e

echo "=================================================="
echo "   Beatmania IIDX (Linux/Wine) Setup Script"
echo "   Optimized for: Omarchy/Arch & Ryzen CPUs"
echo "   Strategy: PipeWire/JACK Realtime (Copilot)"
echo "=================================================="

GAME_DIR="/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500"
PATCH_JSON="$GAME_DIR/patches/LDJ-64ef0ff5_1037754.json"
AVS_CONFIG="$GAME_DIR/prop/avs-config.xml"

# 1. Dependency Check
echo "[+] Checking dependencies..."
MISSING_DEPS=""
if ! command -v wine &> /dev/null; then MISSING_DEPS="$MISSING_DEPS wine"; fi
if ! command -v pw-jack &> /dev/null; then MISSING_DEPS="$MISSING_DEPS pipewire-jack"; fi
if ! command -v chrt &> /dev/null; then MISSING_DEPS="$MISSING_DEPS util-linux"; fi
if ! command -v python3 &> /dev/null; then MISSING_DEPS="$MISSING_DEPS python"; fi

if [ ! -z "$MISSING_DEPS" ]; then
    echo "[-] Missing dependencies: $MISSING_DEPS"
    echo "    Please install them (e.g., sudo pacman -S $MISSING_DEPS)"
    # We continue anyway as some might be optional
fi

# 2. Wine Configuration (Use Pulse/PipeWire properly)
echo "[+] Configuring Wine Registry..."
# Reset to 'pulse' to allow PipeWire to manage the graph
wine reg add "HKCU\Software\Wine\Drivers" /v "Audio" /t REG_SZ /d "pulse" /f > /dev/null 2>&1
# Reset DirectSound buffer (let Pulse handle latency)
wine reg delete "HKCU\Software\Wine\DirectSound" /v "MaxAuxBfSize" /f > /dev/null 2>&1 || true
echo "    -> Audio driver set to Pulse (PipeWire managed)"

# 3. Fix AVS Config Paths (Windows -> Linux Relative)
echo "[+] Patching prop/avs-config.xml..."
if [ -f "$AVS_CONFIG" ]; then
    sed -i 's|src="D:/LDJ/contents/dev/raw"|src="dev/raw"|g' "$AVS_CONFIG"
    sed -i 's|src="D:/LDJ/contents/dev/nvram"|src="dev/nvram"|g' "$AVS_CONFIG"
    echo "    -> Absolute paths converted to relative"
else
    echo "[-] Warning: $AVS_CONFIG not found!"
fi

# 4. Clean Patch JSON (Remove SSE 4.2 / WASAPI conflicts)
echo "[+] Cleaning Patch JSON..."
if [ -f "$PATCH_JSON" ]; then
    python3 - <<EOF
import json
import sys

json_path = "$PATCH_JSON"
try:
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    new_data = []
    removed_count = 0
    
    for item in data:
        if "patches" not in item:
            new_data.append(item)
            continue
            
        name = item.get("name", "")
        # Remove patches that conflict with Wine/Linux audio
        if "SSE4.2 Fix" in name or "WASAPI Shared Mode" in name:
            print(f"    -> Removed bad patch: {name}")
            removed_count += 1
            continue
            
        new_data.append(item)

    if removed_count > 0:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(new_data, f, indent=4)
        print(f"    -> Cleaned {removed_count} patches.")
    else:
        print("    -> No conflicting patches found.")

except Exception as e:
    print(f"[-] Error processing JSON: {e}")
EOF
fi

# 5. Generate Robust Launcher
echo "[+] Generating beatmania-launcher.sh..."
cat > beatmania-launcher.sh <<'EOF'
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
export PULSE_LATENCY_MSEC=60  # Help PulseAudio set a safe client-side buffer
unset DXVK_HUD                # Disable HUD to reduce GPU overhead

# Start Asphyxia (Background)
echo "Starting Asphyxia Core..."
wine asphyxia-core-x64.exe > asphyxia_debug.log 2>&1 &
ASPHYXIA_PID=$!
sleep 5

# Runner Selection: Prefer pw-jack (PipeWire-JACK) for lowest latency
RUN_CMD=""
if command -v pw-jack >/dev/null 2>&1; then
  echo "Using pw-jack (PipeWire JACK compatibility mode)"
  # -iidxsounddevice dsound is still best for Wine compatibility
  RUN_CMD="pw-jack wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound"
else
  echo "Using standard Wine (PulseAudio)"
  RUN_CMD="wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound"
fi

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
EOF

chmod +x beatmania-launcher.sh
echo "    -> Launcher created."

echo "=================================================="
echo "   Setup Complete!"
echo "   Run ./beatmania-launcher.sh to play."
echo "=================================================="
