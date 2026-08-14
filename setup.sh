#!/usr/bin/env bash
# ==============================================================================
# Beatmania IIDX on Linux - Automated Setup & Environment Initializer
# ==============================================================================
# This script sets up all necessary Linux kernel permissions, builds the Rust
# PipeWire audio bridge, checks dependencies, and configures the environment.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}      BEATMANIA IIDX LINUX SETUP & ENVIRONMENT INITIALIZER       ${NC}"
echo -e "${CYAN}================================================================${NC}"

# 1. Dependency checks
echo -e "\n${YELLOW}[1/4] Checking system dependencies...${NC}"
MISSING_DEPS=()
for cmd in wine cargo rustc jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}[-] Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}[!] On Arch Linux / Omarchy: sudo pacman -S wine-staging rust jq curl${NC}"
    echo -e "${YELLOW}[!] On Ubuntu / Debian:     sudo apt install wine rustc cargo jq curl${NC}"
    exit 1
fi
echo -e "${GREEN}[+] All core system tools are installed.${NC}"

# 2. Grant CAP_NET_RAW capability to Wine for e-Amusement ICMP Keepalive
echo -e "\n${YELLOW}[2/4] Configuring Linux Network Capabilities for e-Amusement (CAP_NET_RAW)...${NC}"
echo -e "${CYAN}[*] Granting raw network socket permissions to Wine executables...${NC}"
WINE_BINS=(
    "$(which wine || true)"
    "$(which wine64 || true)"
    "$(which wineserver || true)"
)

for bin in "${WINE_BINS[@]}"; do
    if [ -n "$bin" ] && [ -f "$bin" ]; then
        echo -e "    -> Setting cap_net_raw on $bin"
        sudo setcap cap_net_raw+epi "$bin" 2>/dev/null || true
    fi
done

if [ -d "/usr/lib/wine/x86_64-unix" ]; then
    for lib in /usr/lib/wine/x86_64-unix/wine /usr/lib/wine/x86_64-unix/wine-preloader /usr/lib/wine/x86_64-unix/ws2_32.so; do
        if [ -f "$lib" ]; then
            echo -e "    -> Setting cap_net_raw on $lib"
            sudo setcap cap_net_raw+epi "$lib" 2>/dev/null || true
        fi
    done
fi
echo -e "${GREEN}[+] Network capabilities successfully applied.${NC}"

# 3. Build the Rust PipeWire Audio Bridge
echo -e "\n${YELLOW}[3/4] Building Rust PipeWire Audio Bridge (iidx-sound-bridge)...${NC}"
cd "$SCRIPT_DIR/iidx-sound-bridge"
cargo build --release
cd "$SCRIPT_DIR"
echo -e "${GREEN}[+] iidx-sound-bridge compiled in release mode.${NC}"

# 4. Configuration & Desktop Shortcut
echo -e "\n${YELLOW}[4/4] Setting up configuration & desktop shortcut...${NC}"
if [ ! -f "$SCRIPT_DIR/config.json" ]; then
    echo -e "${YELLOW}[*] Creating config.json from config.example.json...${NC}"
    cp "$SCRIPT_DIR/config.example.json" "$SCRIPT_DIR/config.json"
    echo -e "${GREEN}[+] config.json created! Please edit config.json with your game directory and paths.${NC}"
else
    echo -e "${GREEN}[+] Existing config.json detected.${NC}"
fi

# Install Desktop Shortcut & Icon
mkdir -p "$HOME/.local/share/icons" "$HOME/.local/share/applications"
if [ -f "$SCRIPT_DIR/assets/icon.jpg" ]; then
    cp "$SCRIPT_DIR/assets/icon.jpg" "$HOME/.local/share/icons/beatmania-iidx.jpg"
fi
cat <<EOF > "$HOME/.local/share/applications/beatmania-iidx.desktop"
[Desktop Entry]
Name=Beatmania IIDX 30 RESIDENT
GenericName=Arcade Rhythm Game
Comment=Beatmania IIDX 30 RESIDENT (Linux Arcade Runner with PipeWire 48kHz Audio & e-Amusement)
Exec=$SCRIPT_DIR/launch.sh
Path=$SCRIPT_DIR
Icon=$HOME/.local/share/icons/beatmania-iidx.jpg
Terminal=false
Type=Application
Categories=Game;ArcadeGame;AudioVideo;
Keywords=beatmania;iidx;bemani;konami;resident;arcade;rhythm;
StartupNotify=true
StartupWMClass=spice64.exe
EOF
chmod +x "$HOME/.local/share/applications/beatmania-iidx.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo -e "${GREEN}[+] Desktop shortcut installed to application menu.${NC}"

echo -e "\n${CYAN}================================================================${NC}"
echo -e "${GREEN}  SUCCESS: Your Beatmania IIDX Linux environment is ready!       ${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "To launch the game, run:"
echo -e "  ${YELLOW}./launch.sh${NC}\n"
