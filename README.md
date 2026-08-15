# Beatmania IIDX on Linux (Omarchy / Hyprland / Wayland)

[![Platform: Linux](https://img.shields.io/badge/platform-Linux%20%7C%20Wayland%20%7C%20Hyprland-blue.svg)](https://github.com/Djkawada/Beatmania-IIDX-Linux)
[![Audio: PipeWire WASAPI Bridge](https://img.shields.io/badge/audio-PipeWire%20%7C%2048kHz%20WASAPI%20Low--Latency-purple.svg)](https://github.com/Djkawada/Beatmania-IIDX-Linux)
[![Network: e--Amusement Verified](https://img.shields.io/badge/e--Amusement-100%25%20Verified%20%26%20Working-brightgreen.svg)](https://github.com/Djkawada/Beatmania-IIDX-Linux)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

An all-in-one, production-grade launcher, environment initializer, and native Rust PipeWire audio bridge for running **Beatmania IIDX (tested on IIDX 30 RESIDENT / 31 EPOLIS)** natively on Linux with ultra-low audio latency (< 5ms), perfectly synchronized video/audio, clean digital sound (no clipping/saturation), full turntable controller support, and **100% working local e-Amusement network & player card authentication**.

---

## 🌟 Verified Status

| Component | Status | Details |
|---|---|---|
| **Core Game Execution** | ✅ **100% Working** | Smooth 60 / 120 / 144 / 240+ FPS under Wine + DXVK. |
| **Turntable & Keys** | ✅ **100% Working** | Full 7-key + 14-key + Turntable + VEFX/Effect mapping via Spice2x. |
| **Keysound Latency** | ✅ **Ultra-Low (< 5ms)** | 128-sample PipeWire buffer quantum + `-lowlatencysharedaudio` + 3ms staging. |
| **Clean Digital Audio** | ✅ **No Saturation/Clipping** | `vefx_lock=true` & `effect=OFF` prevents DSP clipping & bass distortion. |
| **Audio-Video Synchronization** | ✅ **100% Synchronized** | Direct frame pacing with monitor refresh rate + 48 kHz hardware clock alignment. |
| **HUD & Performance Monitor** | ✅ **MangoHud Integrated** | Lightweight, unobtrusive top-right FPS / frametime overlay. |
| **Network & Operator Test Mode** | ✅ **100% Working** | `ROUTER`, `CENTER`, `SERVER`, `E-AMUSEMENT` all pass with green OK status. |
| **In-Game e-Amusement & Cards** | ✅ **100% Working** | Title screen e-Amusement pass scanning, PIN entry, and score saving operational. |

---

## 🏗️ Architecture

```mermaid
flowchart TB
    subgraph LinuxHost ["Linux Host (Arch / Omarchy / Ubuntu)"]
        PW["PipeWire / WirePlumber Audio Engine\n(Locked: 48,000 Hz / Quantum: 128 samples = 2.6ms)"]
        Bridge["iidx-sound-bridge (Rust)\n(Ultra-low latency ALSA/WASAPI buffer sync & DAC keep-alive)"]
        Asphyxia["Asphyxia CORE v1.60b\n(Local e-Amusement Server on Port 8083)"]
        Mango["MangoHud\n(Lightweight Top-Right 144/120 FPS Monitor)"]
    end

    subgraph WineEnv ["Wine 64-bit Environment (with CAP_NET_RAW)"]
        Spice["Spice2x (spice64.exe)\n(-url http://127.0.0.1:8083/ -icmphook -iidxsounddevice wasapi -wasapishared -lowlatencysharedaudio)"]
        Game["Beatmania IIDX (bm2dx.dll / avs2-ea3.dll)\n(enable_raw=1 | userdata=1 | userid=1)"]
        CardMgr["Spice2x Card Manager\n(Auto RFID Pass Injector)"]
    end

    Bridge -->|Dynamic Quantum Lock 128| PW
    Game -->|WASAPI Low-Latency Audio Output| Bridge
    Game <-->|Raw ICMP Keepalive & Sockets| Spice
    Spice <-->|XRPC Network & Profile Data| Asphyxia
    CardMgr -->|Card Swipe Event| Game
    Mango -.->|DirectX 9 / Vulkan Hook| Game
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites
Ensure you have the core packages and media plugins installed:
```bash
# On Arch Linux / Omarchy:
sudo pacman -S wine-staging rust jq curl mangohud gst-plugins-ugly gst-plugins-bad gst-libav

# On Ubuntu / Debian:
sudo apt install wine rustc cargo jq curl mangohud gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad gstreamer1.0-libav
```

### 2. Automated Environment Setup
Run the setup script to grant raw network socket permissions (`CAP_NET_RAW`) to Wine and compile the native Rust sound bridge:
```bash
cd ~/Work/iidx-launcher
./setup.sh
```

### 3. Configure Paths
Edit `config.json` (created automatically from `config.example.json`) with your game and wine paths:
```json
{
  "game_dir": "/path/to/Beatmania IIDX/Beatmania 2023090500",
  "asphyxia_exe": "./asphyxia-core",
  "spice_exe": "spice64.exe",
  "wine_prefix": "/home/YOUR_USERNAME/.wine",
  "wine_binary": "/usr/bin/wine",
  "card_id": "E004010000000000",
  "network_url": "http://127.0.0.1:8083/",
  "asphyxia_port": 8083,
  "sound": {
    "device_type": "wasapi",
    "wasapi_mode": "shared",
    "sample_rate": 48000,
    "buffer_quantum": 128,
    "pipewire_latency": "128/48000"
  },
  "display": {
    "windowed": true
  }
}
```

### 4. Launch the Game
```bash
./launch.sh
```

---

## 🛠️ Deep Technical Optimizations & Solutions

### 1. Zero Keysound Latency (WASAPI Low-Latency Engine)
* **Problem**: Standard Wine WASAPI Shared mode buffers audio for 30-50ms. When hitting a key, the sound plays noticeably late relative to the backing track.
* **Solution**: 
  - `iidx-sound-bridge` locks PipeWire quantum to **128 samples** (`2.66ms` latency).
  - Launch with `STAGING_AUDIO_DURATION=3000` (3ms Wine buffer duration).
  - Spice2x flag `-lowlatencysharedaudio` forces the game to use minimal hardware buffer periods.

### 2. Audio Saturation / DSP Frequency Boost Elimination
* **Problem**: In-game audio clips and distorts on bass drops or simultaneous keysounds, sounding like an artificial gain boost.
* **Solution**: 
  - In `config.ini`, lock VEFX to OFF:
    ```ini
    vefx_lock=true
    effect=OFF
    ```
  - In the arcade **Test Menu** (`F2` / `T` -> `7. SOUND OPTIONS`), set `SPEAKER VOLUME` / `OUTPUT LEVEL` to **75% - 80%** to provide ~3dB of digital headroom and prevent multi-sample clipping.

### 3. Display Refresh Rate & Chart Speed Synchronization
* **Problem**: If the display refresh rate (e.g. 144 Hz or 120 Hz) does not match the game's internal frame step divider, the chart moves at the wrong speed or stutters.
* **Solution**: Enable `Force Custom Timing and Adapter Mode in LDJ (Experimental)` in `%appdata%\spice2x\spicetools_patch_manager.json` and set `Choose Custom LDJ Timing/Adapter FPS` to match your active monitor refresh rate (e.g. `144 FPS` or `120 FPS`).

### 4. Audio Clock Matching (Fixing 1.09x Pitch/Tempo Distortion)
* **Problem**: On NVIDIA HDMI / DisplayPort audio sinks, hardware clocks run at **48,000 Hz**. Forcing an un-resampled 44,100 Hz rate creates an 8% slow-motion effect (`0.918x`) and audio drift.
* **Solution**: The included Rust [`iidx-sound-bridge`](iidx-sound-bridge/) locks PipeWire to `48000 Hz` and enforces `PIPEWIRE_LATENCY="128/48000"`, ensuring 1:1 nominal playback speed.

### 5. e-Amusement "Service Unavailable" on Title Screen
* **Root Cause 1 (`CAP_NET_RAW` / Linux Raw Sockets)**:
  Konami's `avs2-ea3.dll` creates raw ICMP ping sockets for `keepalive`. Linux denies raw socket creation to non-root processes (`0x80080016: Permission Denied`).  
  *Fix*: Run `sudo setcap cap_net_raw+epi /usr/bin/wine /usr/bin/wineserver /usr/lib/wine/x86_64-unix/*` (handled by `setup.sh`).
* **Root Cause 2 (`enable_raw` in AVS Configuration)**:
  In `prop/avs-config.xml` and `dev/nvram/avs-config.xml`, `<enable_raw __type="bool">0</enable_raw>` was set to `0`.  
  *Fix*: Set `<enable_raw __type="bool">1</enable_raw>`.
* **Root Cause 3 (`userdata` & `userid` Profile Flags)**:
  In `prop/ea3-config.xml` and `dev/nvram/ea3-config.xml`, `<userdata>` and `<userid>` were set to `0`, causing the game to skip card profile retrieval and boot into guest mode.  
  *Fix*: Set `<userdata __type="u8">1</userdata>` and `<userid __type="u8">1</userid>`.
* **Root Cause 4 (Spice2x Flag Collision)**:
  Running with `-ea` launches Spice2x's internal dummy server which intercepts network traffic.  
  *Fix*: Launch strictly with `-url http://127.0.0.1:8083/ -icmphook`.

---

## 🔒 Privacy & Safe Sharing

This repository contains zero personal paths, usernames, proprietary ROMs, or private e-Amusement card serial numbers.  
- Personal settings are saved in `config.json` (ignored by `.gitignore`).
- Shareable templates are provided in `config.example.json`.

---

## 📜 License
MIT License - Created for the arcade rhythm gaming and Linux preservation community.

