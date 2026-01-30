# Re1-sonos

Modern (actually good) S1 client for macOS in Swift.

## Features

- **Device Discovery** — Automatic SSDP discovery of Sonos S1 speakers on your local network
- **Playback Control** — Play, pause, skip, previous, seek, shuffle, repeat
- **Queue Management** — View, play from, and clear the current queue
- **Volume Control** — Group and per-speaker volume with mute toggle
- **Zone Grouping** — Group/ungroup speakers, manage multi-room setups
- **Now Playing** — Large album art display with track info and progress bar
- **Real-time Updates** — Polling-based state sync with smooth position tracking
- **Modern UI** — Clean SwiftUI interface with sidebar navigation, bottom playback bar

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- Sonos S1 speakers on the same local network

## Building

```bash
cd SonosClient
swift build
```

## Running

```bash
cd SonosClient
swift run
```

Or open `SonosClient/Package.swift` in Xcode and run directly.

## Architecture

```
SonosClient/
├── Sources/SonosClient/
│   ├── App/                    # SwiftUI app entry + main content view
│   ├── Models/                 # Data models (Device, Track, Group, TransportState)
│   ├── Network/                # SSDP discovery, SOAP client, XML parsing
│   ├── Services/               # Business logic (Transport, Rendering, Zone, Events, Coordinator)
│   ├── Views/
│   │   ├── Components/         # Reusable views (AlbumArt, ProgressBar, Volume, PlaybackControls)
│   │   ├── NowPlaying/         # Now playing detail + bottom bar
│   │   ├── Queue/              # Queue list view
│   │   ├── Sidebar/            # Room list + room management
│   │   └── Settings/           # Preferences window
│   ├── Utilities/              # Keyboard shortcuts
│   └── Resources/
└── Package.swift
```

## How It Works

1. **SSDP Discovery** — Sends M-SEARCH multicast to find Sonos ZonePlayers
2. **Device Description** — Fetches UPnP XML from each device for model/room info
3. **Zone Topology** — Queries ZoneGroupTopology to understand speaker groupings
4. **SOAP Control** — Sends UPnP/SOAP commands for playback, volume, and queue operations
5. **State Polling** — Polls transport and volume state for real-time UI updates
