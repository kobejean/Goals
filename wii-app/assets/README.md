# Wii Fit Sync Channel Assets

This directory contains assets for creating a Wii Menu channel.

## Quick Start

1. Generate placeholder icons:
   ```bash
   chmod +x generate_icons.sh
   ./generate_icons.sh
   ```

2. Copy assets to SD card:
   ```
   sd:/apps/wiifitsync/
   ├── boot.dol
   ├── meta.xml
   └── icon.png
   ```

3. The app will appear in Homebrew Channel with the icon.

## Creating a Forwarder Channel (Wii Menu)

To make Wii Fit Sync appear as a channel on the Wii Menu:

### Option A: Using ForwardMii (Windows)

1. Download [ForwardMii](https://github.com/FIX94/ForwardMii)
2. Set SD path to: `sd:/apps/wiifitsync/boot.dol`
3. Import `banner.png` and `icon_large.png`
4. Generate WAD file
5. Install WAD using YAWMM or Wii Mod Lite

### Option B: Using Open-Source Forwarder

1. Clone [hbc-forwarder](https://github.com/FIX94/hbc-forwarder)
2. Modify to point to your app path
3. Build with devkitPro
4. Package as WAD

### Option C: CustomizeMii (Windows)

1. Download [CustomizeMii](https://wiibrew.org/wiki/CustomizeMii)
2. Create new channel from template
3. Import your banner/icon assets
4. Set DOL path and generate WAD

## Asset Specifications

| File | Size | Purpose |
|------|------|---------|
| `icon.png` | 128×48 | Homebrew Channel list icon |
| `icon_large.png` | 128×128 | Wii Menu channel icon |
| `banner.png` | 608×456 | Banner shown when channel is selected |

### Design Tips

- Use simple, recognizable imagery (scale icon, Wii Fit logo style)
- Cyan (#00BCD4) matches the iOS app theme
- Dark background (#1A1A2E) for contrast
- Keep text minimal - icons should be recognizable at small sizes

## Installing the WAD

1. Copy the generated `.wad` file to `sd:/wad/`
2. Launch YAWMM (Yet Another Wad Manager Mod) or Wii Mod Lite
3. Navigate to the WAD file and install
4. The channel appears on your Wii Menu

## Safety Notes

- Forwarder channels are safe - they just redirect to SD card
- The actual app code stays on SD, easy to update
- To uninstall, use the same WAD manager to remove
- Always keep a NAND backup (BootMii) before installing channels
