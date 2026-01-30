# Re1-sonos

Modern (actually good) S1 client for macOS in Swift.

## Features

- **Apple Music Integration** — Browse, search, and play Apple Music directly on Sonos speakers
  - Browse recommendations, charts, and recently played
  - Full library access: playlists, albums, artists, songs
  - Search the Apple Music catalog
  - Album and playlist detail views with track listings
  - Artist pages with top songs and discography
  - Play, shuffle, or add to queue from any view
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
- Apple Music subscription (for Apple Music features)
- Apple Music must be linked in your Sonos system settings

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
│   │   ├── AppleMusic/         # Apple Music browser, search, album/playlist/artist detail
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
6. **Apple Music Bridge** — Translates MusicKit catalog IDs into Sonos-compatible `x-sonos-http:` / `x-rincon-cpcontainer:` URIs with DIDL-Lite metadata envelopes, targeting the linked Apple Music service (sid=204)

## Apple Music Setup

1. Link Apple Music to your Sonos system using the official Sonos app
2. Launch Sonos Client and click the "Apple Music" tab in the sidebar
3. Authorize Apple Music access when prompted
4. Browse, search, and play directly to any Sonos room
