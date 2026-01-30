import Foundation
import Combine

/// Central coordinator that manages device discovery, state polling, and exposes
/// reactive state for the SwiftUI views.
@MainActor
final class SonosCoordinator: ObservableObject {
    // MARK: - Published State

    @Published var devices: [SonosDevice] = []
    @Published var groups: [SonosGroup] = []
    @Published var selectedGroup: SonosGroup?
    @Published var transportInfo: TransportInfo?
    @Published var queue: [Track] = []
    @Published var volume: Int = 0
    @Published var isMuted: Bool = false
    @Published var isDiscovering: Bool = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let discovery = SSDPDiscovery()
    private let transport = TransportService()
    private let rendering = RenderingService()
    private let zoneService = ZoneService()

    // MARK: - State

    private var knownDeviceIPs: Set<String> = []
    private var knownDevices: [String: SonosDevice] = [:] // id -> device
    private var pollingTimer: Timer?
    private var positionTimer: Timer?

    // MARK: - Lifecycle

    func startDiscovery() {
        isDiscovering = true
        knownDeviceIPs.removeAll()

        discovery.search { [weak self] ip, port in
            Task { @MainActor [weak self] in
                await self?.handleDiscoveredDevice(ip: ip, port: port)
            }
        }

        // Stop discovery after a timeout and refresh groups
        Task {
            try? await Task.sleep(for: .seconds(5))
            discovery.stop()
            isDiscovering = false
            await refreshGroups()
            startPolling()
        }
    }

    func stopAll() {
        discovery.stop()
        pollingTimer?.invalidate()
        positionTimer?.invalidate()
        pollingTimer = nil
        positionTimer = nil
    }

    // MARK: - Discovery

    private func handleDiscoveredDevice(ip: String, port: Int) async {
        guard !knownDeviceIPs.contains(ip) else { return }
        knownDeviceIPs.insert(ip)

        do {
            guard let device = try await DeviceDescriptionFetcher.fetch(ip: ip, port: port) else { return }
            knownDevices[device.id] = device
            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
        } catch {
            print("[Discovery] Failed to fetch device at \(ip): \(error)")
        }
    }

    // MARK: - Groups

    func refreshGroups() async {
        guard let anyDevice = devices.first else { return }
        do {
            let xml = try await zoneService.getZoneGroupState(device: anyDevice)
            let parsed = await zoneService.parseZoneGroups(from: xml, knownDevices: knownDevices)
            groups = parsed

            // Update group volumes
            for i in groups.indices {
                if let vol = try? await rendering.getGroupVolume(device: groups[i].coordinator) {
                    groups[i].volume = vol
                }
            }

            // Auto-select first group if none selected
            if selectedGroup == nil, let first = groups.first {
                selectGroup(first)
            } else if let sel = selectedGroup,
                      let updated = groups.first(where: { $0.id == sel.id }) {
                selectedGroup = updated
            }
        } catch {
            errorMessage = "Failed to fetch zone groups: \(error.localizedDescription)"
        }
    }

    func selectGroup(_ group: SonosGroup) {
        selectedGroup = group
        Task {
            await refreshTransport()
            await refreshQueue()
            await refreshVolume()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTimer?.invalidate()
        positionTimer?.invalidate()

        // Poll transport state every 3 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTransport()
            }
        }

        // Update position every second for smooth progress bar
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let info = self.transportInfo, info.state == .playing else { return }
                self.transportInfo?.currentPosition += 1.0
            }
        }
    }

    // MARK: - Transport

    func refreshTransport() async {
        guard let group = selectedGroup else { return }
        do {
            transportInfo = try await transport.getTransportInfo(device: group.coordinator)
        } catch {
            // Silently ignore polling errors
        }
    }

    func play() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.play(device: group.coordinator)
            transportInfo?.state = .playing
        } catch {
            errorMessage = "Play failed: \(error.localizedDescription)"
        }
    }

    func pause() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.pause(device: group.coordinator)
            transportInfo?.state = .paused
        } catch {
            errorMessage = "Pause failed: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() async {
        if transportInfo?.state.isPlaying == true {
            await pause()
        } else {
            await play()
        }
    }

    func next() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.next(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Next failed: \(error.localizedDescription)"
        }
    }

    func previous() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.previous(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Previous failed: \(error.localizedDescription)"
        }
    }

    func seek(to position: TimeInterval) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.seek(device: group.coordinator, to: position)
            transportInfo?.currentPosition = position
        } catch {
            errorMessage = "Seek failed: \(error.localizedDescription)"
        }
    }

    func playTrackFromQueue(trackNumber: Int) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.seekTrack(device: group.coordinator, trackNumber: trackNumber)
            try await transport.play(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Play track failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Play Mode

    func toggleShuffle() async {
        guard let group = selectedGroup, let info = transportInfo else { return }
        let newMode: PlayMode
        switch info.playMode {
        case .normal: newMode = .shuffle
        case .shuffle, .shuffleNoRepeat: newMode = .normal
        case .repeatAll: newMode = .shuffleRepeat
        case .shuffleRepeat: newMode = .repeatAll
        case .repeatOne: newMode = .shuffle
        }
        do {
            try await transport.setPlayMode(device: group.coordinator, mode: newMode)
            transportInfo?.playMode = newMode
        } catch {
            errorMessage = "Shuffle toggle failed: \(error.localizedDescription)"
        }
    }

    func toggleRepeat() async {
        guard let group = selectedGroup, let info = transportInfo else { return }
        let newMode: PlayMode
        switch info.playMode {
        case .normal: newMode = .repeatAll
        case .repeatAll: newMode = .repeatOne
        case .repeatOne: newMode = .normal
        case .shuffle, .shuffleNoRepeat: newMode = .shuffleRepeat
        case .shuffleRepeat: newMode = .shuffle
        }
        do {
            try await transport.setPlayMode(device: group.coordinator, mode: newMode)
            transportInfo?.playMode = newMode
        } catch {
            errorMessage = "Repeat toggle failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Volume

    func refreshVolume() async {
        guard let group = selectedGroup else { return }
        do {
            volume = try await rendering.getGroupVolume(device: group.coordinator)
            isMuted = false // Will be updated via events in future
        } catch {
            // Silently ignore
        }
    }

    func setVolume(_ newVolume: Int) async {
        guard let group = selectedGroup else { return }
        volume = newVolume
        do {
            try await rendering.setGroupVolume(device: group.coordinator, volume: newVolume)
        } catch {
            errorMessage = "Volume failed: \(error.localizedDescription)"
        }
    }

    func toggleMute() async {
        guard let group = selectedGroup else { return }
        isMuted.toggle()
        do {
            try await rendering.setGroupMute(device: group.coordinator, muted: isMuted)
        } catch {
            errorMessage = "Mute toggle failed: \(error.localizedDescription)"
        }
    }

    func setDeviceVolume(_ device: SonosDevice, volume: Int) async {
        do {
            try await rendering.setVolume(device: device, volume: volume)
        } catch {
            errorMessage = "Device volume failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Queue

    func refreshQueue() async {
        guard let group = selectedGroup else { return }
        do {
            queue = try await transport.getQueue(device: group.coordinator)
        } catch {
            errorMessage = "Queue fetch failed: \(error.localizedDescription)"
        }
    }

    func clearQueue() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.removeAllTracksFromQueue(device: group.coordinator)
            queue.removeAll()
        } catch {
            errorMessage = "Clear queue failed: \(error.localizedDescription)"
        }
    }

    func removeFromQueue(trackNumber: Int) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.removeTrackFromQueue(device: group.coordinator, trackNumber: trackNumber)
            await refreshQueue()
        } catch {
            errorMessage = "Remove track failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Group Management

    func groupDevices(_ device: SonosDevice, with coordinator: SonosDevice) async {
        do {
            try await zoneService.joinGroup(device: device, coordinatorDevice: coordinator)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshGroups()
        } catch {
            errorMessage = "Group failed: \(error.localizedDescription)"
        }
    }

    func ungroupDevice(_ device: SonosDevice) async {
        do {
            try await zoneService.leaveGroup(device: device)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshGroups()
        } catch {
            errorMessage = "Ungroup failed: \(error.localizedDescription)"
        }
    }
}
