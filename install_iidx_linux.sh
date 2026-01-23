#!/bin/bash
set -e

echo "=================================================="
echo "   Beatmania IIDX (Linux/Wine) Setup Script"
echo "   Optimized for: Omarchy/Arch & Ryzen CPUs"
echo "=================================================="

GAME_DIR="/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500"
PATCH_JSON="$GAME_DIR/patches/LDJ-64ef0ff5_1037754.json"
AVS_CONFIG="$GAME_DIR/prop/avs-config.xml"

# 1. Dependency Check
echo "[+] Checking dependencies..."
MISSING_DEPS=""
if ! command -v wine &> /dev/null; then MISSING_DEPS="$MISSING_DEPS wine"; fi
if ! command -v pw-metadata &> /dev/null; then MISSING_DEPS="$MISSING_DEPS pipewire-tools"; fi
if ! command -v python3 &> /dev/null; then MISSING_DEPS="$MISSING_DEPS python"; fi

if [ ! -z "$MISSING_DEPS" ]; then
    echo "[-] Missing dependencies: $MISSING_DEPS"
    echo "    Please install them (e.g., sudo pacman -S $MISSING_DEPS)"
    exit 1
fi

# 2. Wine Configuration (The "Golden Audio" Setup)
echo "[+] Configuring Wine Registry..."
# Force ALSA driver to bypass PulseAudio layer latency/issues
wine reg add "HKCU\Software\Wine\Drivers" /v "Audio" /t REG_SZ /d "alsa" /f > /dev/null 2>&1
# Set DirectSound buffer size
wine reg add "HKCU\Software\Wine\DirectSound" /v "MaxAuxBfSize" /t REG_SZ /d "256" /f > /dev/null 2>&1
echo "    -> Audio driver set to ALSA"
echo "    -> DirectSound buffer optimized"

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

    # Filter out problematic patches
    new_data = []
    removed_count = 0
    
    # We keep the header (first item usually contains metadata) and filter the rest
    for item in data:
        # Keep metadata blocks
        if "patches" not in item:
            new_data.append(item)
            continue
            
        # Filter logic
        name = item.get("name", "")
        if "SSE4.2 Fix" in name:
            print(f"    -> Removed bad patch: {name}")
            removed_count += 1
            continue
        if "WASAPI Shared Mode" in name:
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
else
    echo "[-] Warning: Patch file not found at $PATCH_JSON"
fi

# 5. Generate Launcher
echo "[+] Generating beatmania-launcher.sh..."
cat > beatmania-launcher.sh <<'EOF'
#!/bin/bash

# Path to the game directory
GAME_DIR="/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500"

if [ ! -d "$GAME_DIR" ]; then
    echo "Error: Game directory not found at $GAME_DIR"
    exit 1
fi

cd "$GAME_DIR"

# Cleanup
killall -9 asphyxia-core-x64.exe spice64.exe 2>/dev/null

# 1. Pipewire Optimization (Hardware Level)
# Force 44.1kHz and 1024 quantum for ALSA stability
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
# -iidxsounddevice dsound: Use DirectSound (which maps to ALSA via our Registry fix)
# PULSE_LATENCY_MSEC=60: Safety buffer for ALSA/Pulse bridge
echo "Starting Beatmania IIDX..."
export DXVK_HUD=1
export PULSE_LATENCY_MSEC=60
wine spice64.exe -url http://localhost:8083 -card0 E00401D700D2BFCB -iidx -w -iidxsounddevice dsound

# 4. Cleanup
echo "Game exited. Cleaning up..."
if command -v pw-metadata >/dev/null 2>&1; then
    pw-metadata -n settings 0 clock.force-rate 0
    pw-metadata -n settings 0 clock.force-quantum 0
fi
kill $ASPHYXIA_PID
EOF

chmod +x beatmania-launcher.sh
echo "    -> Launcher created and permissions set."

echo "=================================================="
echo "   Installation Complete!"
echo "   Run ./beatmania-launcher.sh to play."
echo "=================================================="
