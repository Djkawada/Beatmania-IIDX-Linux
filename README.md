# Beatmania IIDX on Linux (Wine + Spice2x + Asphyxia Core)

A complete, high-performance, native Linux launcher and toolset for running modern **Beatmania IIDX (LDJ / TDJ)** under **Wine / Proton (Wayland & Hyprland)** with low-latency PipeWire audio and local e-Amusement server support.

---

## 🏗️ System Architecture

```
                                  ┌─────────────────────────────┐
                                  │   Beatmania IIDX (Wine)     │
                                  │   (Spice2x / bm2dx.dll)     │
                                  └──────────────┬──────────────┘
                                                 │ (Audio: WASAPI 48kHz)
                                                 ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│    PipeWire Audio Stack     │◄──┤   iidx-sound-bridge (Rust)  │
│ (Low Latency Quantum 256)   │   │  (Locks 48kHz HDMI Clock)   │
└─────────────────────────────┘   └─────────────────────────────┘
                                                 │
                                                 │ (XRPC :8083)
                                                 ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│   Asphyxia Core (Native)    │◄──┤    iidx-ea-proxy (Rust)     │
│   (Port 8084 / iidx plugin) │   │ (Region JP + URL Rewriter)  │
└─────────────────────────────┘   └─────────────────────────────┘
```

### Key Components

1. **Automated Launcher (`launch.sh`)**:
   - Single-entrypoint script.
   - Automatically builds Rust binaries (`iidx-ea-proxy` and `iidx-sound-bridge`) if updated.
   - Manages Asphyxia Core daemon lifecycle.
   - Configures Wine environment variables, DXVK, and PipeWire latency overrides.
2. **Audio Sync Bridge (`iidx-sound-bridge/`)**:
   - Native Rust daemon using CPAL and PipeWire settings.
   - Locks PipeWire audio to **48,000 Hz** (native HDMI audio rate) to prevent pitch/tempo drift (fixing the 1.088x speed acceleration bug).
3. **XRPC EA Proxy (`iidx-ea-proxy/`)**:
   - Native Rust HTTP proxy listening on port `8083` and proxying to Asphyxia Core on `8084`.
   - Injects `X-Compress: none` and `Accept-Encoding: identity` on upstream calls to prevent binary LZ77 stream corruption during XML inspection.
   - Performs byte-level replacements for service endpoints (`http://127.0.0.1:8084` -> `8083`) and Japanese arcade cabinet country codes (`JP` / `日本`).
4. **Patches & Timing**:
   - **`CS-style Song Start Delay`**: Adds a 2-second pre-roll delay before chart playback, ensuring 3D lanes, textures, shaders, and audio buffers are fully loaded before notes begin falling.
   - **`Disable Background Movies`**: Avoids video decoding micro-stutters under DX9.

---

## 📁 Repository Structure

```
├── config.example.json      # Template configuration with placeholders
├── launch.sh                # Main executable launcher
├── iidx-ea-proxy/           # Native Rust XRPC EA Proxy
│   ├── Cargo.toml
│   └── src/main.rs
├── iidx-sound-bridge/       # Native Rust Audio Latency & Clock Bridge
│   ├── Cargo.toml
│   └── src/main.rs
├── start_asphyxia.sh        # Dedicated Asphyxia starter script
├── start_game.sh            # Standalone game launch script
└── README.md                # Project documentation
```

---

## ⚙️ Configuration Setup

Your personal configuration is kept in `config.json` (which is ignored by git to protect your personal paths and card ID).

1. Copy the example configuration template:
   ```bash
   cp config.example.json config.json
   ```

2. Edit `config.json` with your personal settings:

```json
{
  "game_dir": "/path/to/Beatmania IIDX/game_directory",
  "asphyxia_exe": "./asphyxia-core",
  "spice_exe": "spice64.exe",
  "wine_prefix": "/home/YOUR_USERNAME/.wine",
  "wine_binary": "/usr/bin/wine",
  "card_id": "E004010000000000",
  "network_url": "http://127.0.0.1:8083/",
  "asphyxia_port": 8084,
  "sound": {
    "device_type": "wasapi",
    "wasapi_mode": "shared",
    "sample_rate": 48000,
    "buffer_quantum": 256,
    "pipewire_latency": "256/48000"
  },
  "display": {
    "windowed": true
  }
}
```

### 🔒 Where to replace personal information:
* **`game_dir`**: Replace with the absolute path to your Beatmania IIDX game directory containing `spice64.exe` and `bm2dx.dll`.
* **`wine_prefix`**: Replace `/home/YOUR_USERNAME/.wine` with your active Wine prefix path.
* **`wine_binary`**: Set to your Wine executable (e.g. `/usr/bin/wine`, `wine`, or a custom Proton runner).
* **`card_id`**: Replace `E004010000000000` with your 16-character e-Amusement card number / NFC UID.
* **`sound.sample_rate`**: Set to `48000` for HDMI/DisplayPort audio or `44100` for legacy dedicated DACs.

---

## 🚀 How to Run

```bash
# Clone the repository
git clone https://github.com/Djkawada/Beatmania-IIDX-Linux.git ~/Work/iidx-launcher
cd ~/Work/iidx-launcher

# Create and adjust your personal config
cp config.example.json config.json
nano config.json

# Launch game & all background services
./launch.sh
```

---

## 📊 Current Status & Known Issues

| Component | Status | Description |
|---|---|---|
| **Platine / Turntable & I/O** | ✅ Working | Verified and functional via Spice2x / `spicecfg.exe`. |
| **Audio Playback & Tempo** | ✅ Fixed | Locked to 48kHz HDMI; pitch and tempo play at exact 1.000x speed. |
| **Song Start Sync** | ✅ Fixed | `CS-style Song Start Delay` eliminates frame-1 asset loading lag. |
| **DirectX 9 / Vulkan (DXVK)** | ✅ Working | Smooth D3D9 rendering over Vulkan. |
| **e-Amusement Service (In-Game)** | 🟡 Active Debugging | **Current Issue**: While the initial network boot check and Operator Test Mode report OK/connected (`services.get`, `facility.get`, `pcbtracker.alive`), right on the title / attract screen the game displays an in-game error stating that the **e-Amusement service is unavailable**. Card login and profile retrieval remain blocked in-game. |

> [!WARNING]
> **Pending Debugging Focus**:  
> Right on the title screen, the game shows the e-Amusement unavailable error. Ongoing investigation covers XRPC service registration (`IIDX30pc` / `cardmng`), cab validation XML structures, and Spice2x RFID card reader event handling.
