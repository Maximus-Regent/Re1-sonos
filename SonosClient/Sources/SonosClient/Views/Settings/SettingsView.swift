import SwiftUI

/// Application settings/preferences window.
struct SettingsView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @AppStorage("pollingInterval") private var pollingInterval: Double = 3.0
    @AppStorage("showAlbumArt") private var showAlbumArt: Bool = true
    @AppStorage("autoDiscoverOnLaunch") private var autoDiscoverOnLaunch: Bool = true
    @AppStorage("maxVolume") private var maxVolume: Double = 100

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            networkSettings
                .tabItem {
                    Label("Network", systemImage: "network")
                }

            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Toggle("Auto-discover on launch", isOn: $autoDiscoverOnLaunch)

            Toggle("Show album artwork", isOn: $showAlbumArt)

            HStack {
                Text("Max volume limit")
                Spacer()
                Slider(value: $maxVolume, in: 10...100, step: 5)
                    .frame(width: 150)
                Text("\(Int(maxVolume))%")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 36)
            }

            HStack {
                Text("Polling interval")
                Spacer()
                Slider(value: $pollingInterval, in: 1...10, step: 0.5)
                    .frame(width: 150)
                Text("\(String(format: "%.1f", pollingInterval))s")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 36)
            }
        }
        .padding(20)
    }

    // MARK: - Network

    private var networkSettings: some View {
        Form {
            Section("Discovered Devices") {
                if coordinator.devices.isEmpty {
                    Text("No devices found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(coordinator.devices, id: \.id) { device in
                        HStack {
                            Image(systemName: device.icon)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(device.roomName)
                                    .font(.system(size: 13))
                                Text("\(device.modelName) - \(device.ip):\(device.port)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("v\(device.softwareVersion)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Button("Re-discover") {
                coordinator.startDiscovery()
            }
            .disabled(coordinator.isDiscovering)
        }
        .padding(20)
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Sonos Client")
                .font(.title2.bold())

            Text("A modern macOS client for Sonos S1 systems")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text("Built with SwiftUI")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(20)
    }
}
