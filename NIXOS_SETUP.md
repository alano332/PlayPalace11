# PlayPalace - Running on NixOS

## Quick Start

### Server (Ready to Use)
```bash
# Start the server
./run_server.sh

# Or with custom port
./run_server.sh --port 9000

# With SSL
./run_server.sh --ssl-cert /path/to/cert.pem --ssl-key /path/to/key.pem
```

### Client

**Status:** Client works in **silent mode** (no sound effects) unless audio is configured.

```bash
# Run client (silent mode is OK)
./run_client.sh

# Headless GUI smoke tests (launches Xvfb screen 0 @ 1024x768x24)
PLAYPALACE_USE_XVFB=1 ./run_client.sh
```

The launcher now enters the pinned flake devshell automatically—no extra `.venv` or manual `pip install` needed.

**Expected Warnings (can be ignored):**
- `Gtk-WARNING`: UI layout warnings (cosmetic only)
- `Cannot find Speech Dispatcher`: Accessibility feature (optional)
- `Cannot find espeak`: Text-to-speech (optional)
- `Warning: Could not initialize audio output`: Audio device not available (silent mode)

The client functions normally for gameplay despite these warnings.

#### Creating Your Account

**There are no default accounts!** You need to register:

1. **First user registered** = Auto-approved as Server Owner (full admin)
2. **Additional users** = Require admin approval

To create your admin account:
1. Start server: `./run_server.sh`
2. Start client: `./run_client.sh`
3. Click "Register" and choose your username/password
4. You'll be logged in as Server Owner (first user only)

#### Enabling Audio (Optional)

If you want sound effects, configure an audio system:

```bash
# Check if audio works
speaker-test -t wav -c 2

# For PulseAudio
pulseaudio --start

# For PipeWire
systemctl --user start pipewire pipewire-pulse
```

Then restart the client.

## What Works

✅ Server - fully functional  
✅ Client - fully functional (silent mode)  
⚠️  Client audio - requires audio device configuration

## Built Packages

Pre-built wheels are available in:
- `server/dist/playpalace_server-11.0.0-py3-none-any.whl` (637 KB)
- `client/dist/playpalace_client-11.0.0-py3-none-any.whl` (53 MB)

## Development

### Running Tests
```bash
# Server tests (enter the flake devshell)
nix --extra-experimental-features "nix-command flakes" \
  develop . \
  --command bash -c "cd server && uv run pytest"

# Quick verification
./test_run.sh
```

### Building from Source
```bash
./build.sh
```

## Recent Fixes (2026-01-30)

- ✅ Fixed audio initialization gracefully falls back to silent mode
- ✅ Fixed wxAssertionError spam from menu_list.py
- ✅ Fixed RuntimeError when closing client window
- ✅ Fixed ambience playback crash in silent mode

## Technical Notes

- **Pinned environment:** `flake.nix` / `flake.lock` capture the exact nixpkgs revision plus Python wheels (wxPython, websockets 16, accessible-output2, sound-lib, etc.).
- **Server:** Uses uv for dependency management but now runs inside the pinned flake devshell.
- **Client:** Uses wxPython + the same pinned Python deps—no ad-hoc `.venv`.
- **Audio:** Client uses the BASS audio library which requires a functional audio device.
- **Silent/headless:** When no audio device is found, the client runs without sound. Set `PLAYPALACE_USE_XVFB=1` for GUI testing on headless builders.
