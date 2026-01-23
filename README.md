# Beatmania IIDX Linux Setup

Automated setup scripts for running Beatmania IIDX (SpiceTools) on Linux (Arch/Omarchy) with Wine.

## Features
- **Audio:** Configures Wine to use ALSA directly (bypassing PulseAudio latency) and sets correct buffer sizes for DirectSound.
- **Fixes:** Automatically patches `avs-config.xml` to use Linux-compatible relative paths.
- **Stability:** Removes conflicting "SSE 4.2" and "WASAPI" patches from SpiceTools JSON config to prevent crashes on modern Wine versions.
- **Launcher:** Includes a tuned `beatmania-launcher.sh` with optimal latency settings (60ms).

## Usage

1. Place your game data in `/home/pierre/Games/Beatmania IIDX/Beatmania 2023090500` (or edit the script variables).
2. Run the installer to set up the environment and generate the launcher:
   ```bash
   ./install_iidx_linux.sh
   ```
3. Launch the game:
   ```bash
   ./beatmania-launcher.sh
   ```

## Requirements
- Wine
- Pipewire / PulseAudio (for the system)
- Python 3
