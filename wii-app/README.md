# Wii Fit Sync

Homebrew application for syncing Wii Fit body measurements and exercise data to the Goals iOS app.

## Features

- Reads Wii Fit / Wii Fit Plus save data from NAND
- Extracts body measurements (weight, BMI, balance)
- Serves data over TCP for iOS app to fetch
- Supports multiple profiles

## Building

### Prerequisites

1. Install [devkitPro](https://devkitpro.org/wiki/Getting_Started):

   **macOS:**
   ```bash
   # Download the latest .pkg installer from:
   # https://github.com/devkitPro/pacman/releases

   # Install via Terminal:
   sudo installer -pkg /path/to/devkitpro-pacman-installer.pkg -target /

   # Reboot to set environment variables, then install Wii dev tools:
   sudo dkp-pacman -S wii-dev
   ```

   **Linux:**
   ```bash
   # Follow instructions at https://devkitpro.org/wiki/devkitPro_pacman
   # Then install Wii dev tools:
   sudo dkp-pacman -S wii-dev
   ```

2. Ensure environment variables are set (add to `~/.zshrc` or `~/.bash_profile`):
   ```bash
   export DEVKITPRO=/opt/devkitpro
   export DEVKITPPC=${DEVKITPRO}/devkitPPC
   export PATH=${DEVKITPRO}/tools/bin:$PATH
   ```

### Build

```bash
cd wii-app
make
```

This produces `boot.dol` which is the homebrew executable.

### Clean

```bash
make clean
```

### Deploy over Network

Instead of moving the SD card back and forth, you can send the app directly to your Wii:

```bash
make run
```

This uses `wiiload` to send `boot.dol` to the Wii over the network. Requirements:
- Homebrew Channel must be open on the Wii (at the main menu, not inside an app)
- Both devices on the same network
- Edit `WIILOAD` in Makefile if your Wii's IP changes

## Installation

1. Copy the built files to your SD card:
   ```
   SD:/apps/wiifitsync/boot.dol   (from wii-app/boot.dol after build)
   SD:/apps/wiifitsync/meta.xml   (from wii-app/meta.xml)
   ```

2. Add the icon for Homebrew Channel:
   ```
   SD:/apps/wiifitsync/icon.png    (from wii-app/icon.png)
   ```

### Creating a Wii Menu Channel (Optional)

To launch Wii Fit Sync directly from the Wii Menu (without going through Homebrew Channel):

1. Generate channel assets:
   ```bash
   cd assets
   ./generate_icons.sh
   ```

2. Use a forwarder tool like [ForwardMii](https://github.com/FIX94/ForwardMii) to create a WAD:
   - Set path to `sd:/apps/wiifitsync/boot.dol`
   - Import the generated banner and icon images

3. Install the WAD using YAWMM or Wii Mod Lite

See `assets/README.md` for detailed instructions.

## Usage

1. Insert the SD card into your Wii
2. Launch the Homebrew Channel
3. Select "Wii Fit Sync"
4. Note the IP address displayed on screen
5. On iOS:
   - Open the Goals app
   - Go to Settings > Wii Fit
   - Enter the IP address
   - Tap "Test Connection"
   - Tap "Sync" to transfer data

## Protocol

The app runs a simple TCP server on port 8888.

### Sync Request
```json
{"action": "sync"}
```

### Sync Response (Success)
```json
{
  "version": 2,
  "profiles": [{
    "name": "Player1",
    "height_cm": 175,
    "dob": "1990-05-15",
    "measurements": [{
      "date": "2024-01-15T09:30:00",
      "weight_kg": 75.5,
      "bmi": 24.69,
      "balance_percent": 50.5
    }],
    "activities": []
  }]
}
```

### Sync Response (Error)
```json
{
  "version": 2,
  "error": {
    "code": -2,
    "message": "Save file not found"
  }
}
```

### Acknowledgment
After receiving data, send:
```json
{"action": "ack"}
```

## Save File Format

### Body Measurements

Located at offset `0x38A1` from profile start, 21-byte records:

| Offset | Size | Description |
|--------|------|-------------|
| +0 | 4 | Date bitfield (year:11, month:4, day:5, hour:5, min:6) |
| +4 | 2 | Weight (kg × 10, big-endian) |
| +6 | 2 | BMI (× 100, big-endian) |
| +8 | 2 | Balance (% × 10, big-endian) |
| +10 | 11 | Extended test data |

### Profile Header

| Offset | Size | Description |
|--------|------|-------------|
| 0x08 | 20 | Mii name (UTF-16BE, 10 chars) |
| 0x1F | 1 | Height (cm) |
| 0x20 | 4 | DOB (BCD: YY YY MM DD) |

Profile size: 0x9289 bytes

## Troubleshooting

### "Save file not found"
- Ensure you have played Wii Fit at least once
- The save data must be on the Wii's internal NAND, not an SD card

### "Network init failed"
- Check that your Wii has a WiFi connection
- The Wii must be on the same network as your iOS device

### iOS app can't connect
- Verify the IP address is correct
- Ensure no firewall is blocking port 8888
- Try restarting the Wii app

## License

MIT License - See the main Goals repository for details.
