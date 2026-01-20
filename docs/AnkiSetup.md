# Anki Integration Setup

This guide explains how to connect the Goals app to Anki for tracking your spaced repetition learning progress.

## Prerequisites

1. **Anki Desktop** installed on your computer (Windows, macOS, or Linux)
   - Download from [https://apps.ankiweb.net](https://apps.ankiweb.net)

2. **AnkiConnect plugin** installed in Anki
   - This plugin exposes Anki's data via a local API

## Step 1: Install AnkiConnect

1. Open Anki Desktop
2. Go to **Tools** → **Add-ons**
3. Click **Get Add-ons...**
4. Enter the code: `2055492159`
5. Click **OK** to install
6. Restart Anki

## Step 2: Configure Network Access (Optional)

By default, AnkiConnect only accepts connections from `localhost`. If you're running Anki on a different machine than your iOS device (using a Mac as the server), you need to allow network access:

1. In Anki, go to **Tools** → **Add-ons**
2. Select **AnkiConnect** and click **Config**
3. Change the configuration:

```json
{
    "apiKey": null,
    "apiLogPath": null,
    "ignoreOriginList": [],
    "webBindAddress": "0.0.0.0",
    "webBindPort": 8765,
    "webCorsOriginList": ["*"]
}
```

4. Click **OK** and restart Anki

**Security Note:** Setting `webBindAddress` to `0.0.0.0` allows connections from any device on your network. Only do this on trusted networks.

## Step 3: Find Your Computer's IP Address

If connecting from an iOS device to Anki on a computer:

### macOS
1. Open **System Settings** → **Network**
2. Select your active connection (Wi-Fi or Ethernet)
3. Your IP address is shown (e.g., `192.168.1.100`)

### Windows
1. Open **Command Prompt**
2. Type `ipconfig` and press Enter
3. Look for **IPv4 Address** under your active adapter

### Linux
1. Open Terminal
2. Type `ip addr` or `hostname -I`

## Step 4: Configure Goals App

1. Open the Goals app
2. Go to **Settings**
3. In the **Anki** section:
   - **Host**: Enter your computer's IP address (e.g., `192.168.1.100`)
     - Use `localhost` or `127.0.0.1` if running on the same machine (simulator)
   - **Port**: `8765` (default AnkiConnect port)
   - **Decks**: Leave empty for all decks, or enter comma-separated deck names to track specific ones (e.g., `Japanese, Spanish`)
4. Tap **Test Connection** to verify the setup

## Step 5: Verify Connection

A successful connection will show:
- **Connected** status with a green checkmark

If you see **Disconnected**:
- Ensure Anki Desktop is running
- Verify AnkiConnect is installed (check Tools → Add-ons)
- Check the IP address and port are correct
- Make sure your device is on the same network as the computer running Anki

## Tracked Metrics

Once connected, Goals will track:

| Metric | Description |
|--------|-------------|
| **Daily Reviews** | Number of cards reviewed each day |
| **Study Time** | Minutes spent studying |
| **Retention Rate** | Percentage of correct answers |
| **New Cards** | Number of new cards learned |
| **Current Streak** | Consecutive days with reviews |
| **Longest Streak** | Best streak achieved |

## Offline Mode

The Goals app caches your Anki data locally. This means:
- Your stats remain visible even when Anki isn't running
- Data syncs automatically when Anki is available
- Historical data is preserved across sessions

## Troubleshooting

### "Unable to connect to Anki"
- Verify Anki Desktop is running
- Check that AnkiConnect add-on is installed
- Confirm the host IP and port are correct
- Ensure both devices are on the same network

### No data showing
- Review some cards in Anki first
- Pull down to refresh in the Goals app
- Check that the configured decks exist (if filtering)

### Connection works but data is incomplete
- AnkiConnect returns review history, which may not include very old data
- The app caches data over time, building a complete history

### iOS Simulator Testing
When testing in the iOS Simulator:
- Use `localhost` or `127.0.0.1` as the host
- Anki must be running on the same Mac

## API Reference

For developers, AnkiConnect exposes these endpoints used by Goals:

```bash
# Check connection
curl -X POST http://localhost:8765 -d '{"action": "version", "version": 6}'

# Get deck names
curl -X POST http://localhost:8765 -d '{"action": "deckNames", "version": 6}'

# Get card reviews for a deck
curl -X POST http://localhost:8765 -d '{
  "action": "cardReviews",
  "version": 6,
  "params": {"deck": "Default", "startID": 0}
}'
```

## More Information

- [AnkiConnect Documentation](https://foosoft.net/projects/anki-connect/)
- [Anki Manual](https://docs.ankiweb.net)
