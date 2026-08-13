# Beatmania IIDX Linux Launcher

> **Ultra-Low Latency Audio, DXVK Vulkan Rendering, and Native Server Integration for Beatmania IIDX on Linux**

An automated, high-performance launcher and setup suite for running **Beatmania IIDX** (SpiceTools / Spice2X) on modern Linux distributions (Arch Linux, Omarchy, Hyprland, Wayland).

---

## 🚀 Architectural Overview

Running BEMANI arcade titles on Linux via Wine has historically presented major technical hurdles: audio timing drift, WASAPI buffer underruns, Wayland presentation freezes, and AVS2 network RPC errors. This repository addresses each layer with native Linux tooling.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Beatmania IIDX (spice64.exe)                         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
┌───────────────────────┐                         ┌──────────────────────┐
│  Direct3D 9 (DXVK)    │                         │  WASAPI Shared Audio │
│  Vulkan Rendering     │                         │  44.1 kHz / 256 Q    │
└──────────┬────────────┘                         └──────────┬───────────┘
           │                                                 │
           ▼                                                 ▼
┌───────────────────────┐                         ┌──────────────────────┐
│ System Wine 11.15     │                         │ iidx-sound-bridge    │
│ (Native Wayland WM)   │                         │ (Rust PipeWire Lock) │
└───────────────────────┘                         └──────────┬───────────┘
                                                             │
                                                             ▼
                                                  ┌──────────────────────┐
                                                  │ PipeWire / DAC (ALSA)│
                                                  └──────────────────────┘
```

---

## ⚡ The Advanced Audio Solution: `iidx-sound-bridge`

### The Linux Audio Timing Problem
Beatmania IIDX relies on exact **44.1 kHz** audio sampling with strict buffer quanta (**256 samples** ≈ 5.8 ms latency). On Linux:
1. Desktop audio servers (PipeWire / PulseAudio) default to **48.0 kHz** sampling and dynamic quantum scaling.
2. Running Windows WASAPI inside Wine over a 48.0 kHz PipeWire graph forces continuous sample rate conversion (SRC) and buffer resizing.
3. This results in micro-stutters, audio crackling, and timing drift on turntable scratches and keypresses.

### How `iidx-sound-bridge` Solves It
`iidx-sound-bridge` is a custom real-time audio service written in **Rust** located in [`iidx-sound-bridge/`](./iidx-sound-bridge):

* **Clock & Quantum Lock**: Interacts directly with PipeWire's control metadata (`pw-metadata`) to lock the system audio clock rate strictly to **44.1 kHz (`1/44100`)** and quantum size to **256 samples (`256/44100`)**.
* **Zero-Resampling Passthrough**: Ensures Wine's WASAPI driver streams audio directly to your DAC at 44.1 kHz without PipeWire applying software resampling.
* **Low Latency WASAPI Shared Mode**: `launch.sh` launches `spice64.exe` with `-iidxsounddevice wasapi -wasapishared` and overrides `WINEDLLOVERRIDES="mmdevapi=n,b;dsound=n,b"`, achieving near-zero audio latency under 6 ms.

---

## 🎨 Graphics & Display Engine (System Wine 11.15 + DXVK)

* **Proton vs System Wine**: Valve's Proton preloader environment can introduce window presentation hangs under Wayland/Hyprland after title screen rendering. This launcher uses standard **System Wine (Wine 11.15)** (`/usr/bin/wine`).
* **Vulkan Direct3D 9 (DXVK)**: Utilizes DXVK (`d3d9.dll`) to translate Direct3D 9 API calls directly into Vulkan command buffers, giving stable 144Hz+ framerates and smooth frame pacing.
* **Tiling WM Support**: Configured for Wayland tiling window managers like Hyprland with windowed mode (`-w`) support.

---

## 🌐 Network Configuration & Asphyxia Core Integration

* **Native Asphyxia Execution**: Launches native Linux `./asphyxia-core` on port `8083` with `-b 0.0.0.0 -pa 127.0.0.1 --dev`.
* **AVS2 XML Parser Fix**: Unslashed URLs (`http://127.0.0.1:8083`) in `prop/ea3-config.xml` and `plugins/iidx@asphyxia/index.ts` resolve AVS2 `property_mem_read()` errors (`5-2002-0916` / `80092182`).
* **RPC Endpoint Verification**: All fundamental RPC services (`services.get`, `pcbtracker.alive`, `package.list`, `message.get`, `facility.get`) return clean `HTTP 200 OK`.

> [!NOTE]
> **e-Amusement Card Services Note**: Full in-game e-Amusement card authentication and network participation are **currently undergoing active investigation**. I am yet to find a complete way to make full e-amusement card services available in-game without the AVS2 network subsystem restricting card login on certain game builds.

---

## 📁 Repository Structure

```text
.
├── config.json          # Main configuration (game paths, wine binary, audio options)
├── launch.sh            # 1-click master launcher script
├── start_asphyxia.sh    # Standalone Asphyxia server runner
├── iidx-sound-bridge/   # Rust PipeWire 44.1kHz / 256 quantum audio clock bridge
└── iidx-ea-proxy/       # Optional EA3 proxy component
```

---

## ⚙️ Configuration (`config.json`)

```json
{
  "game_dir": "/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500",
  "asphyxia_exe": "./asphyxia-core",
  "spice_exe": "spice64.exe",
  "wine_prefix": "/home/pierre/.wine",
  "wine_binary": "/usr/bin/wine",
  "card_id": "E00401D700D2BFCB",
  "network_url": "http://127.0.0.1:8083",
  "asphyxia_port": 8083,
  "sound": {
    "device_type": "wasapi",
    "wasapi_mode": "shared",
    "sample_rate": 44100,
    "buffer_quantum": 256,
    "pipewire_latency": "256/44100"
  },
  "display": {
    "windowed": true
  }
}
```

---

## 🎮 How to Run

1. Make scripts executable:
   ```bash
   chmod +x launch.sh start_asphyxia.sh
   ```
2. Start the game:
   ```bash
   ./launch.sh
   ```

### Default In-Game Controls
- **P1 Start**: `1` (or `Enter`)
- **Insert Coin**: `5`
- **Spice Overlay Menu**: `Ctrl + F1` or `F11` (access input remapping, card controls, and settings live).
