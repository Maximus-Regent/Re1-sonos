import SwiftUI

/// Per-device volume control, used in group management views.
struct VolumeControlView: View {
    let device: SonosDevice
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var volume: Double = 50
    @State private var isLoading = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Slider(value: $volume, in: 0...100, step: 1) { editing in
                if !editing {
                    Task {
                        await coordinator.setDeviceVolume(device, volume: Int(volume))
                    }
                }
            }
            .controlSize(.small)

            Text("\(Int(volume))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
        .task {
            // Load initial volume
            let rendering = RenderingService()
            if let vol = try? await rendering.getVolume(device: device) {
                volume = Double(vol)
            }
            isLoading = false
        }
        .opacity(isLoading ? 0.5 : 1)
    }

    private var volumeIcon: String {
        if volume == 0 { return "speaker.fill" }
        if volume < 33 { return "speaker.wave.1.fill" }
        if volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Group volume control for the selected group.
struct GroupVolumeControl: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 12) {
            // Group volume
            HStack(spacing: 8) {
                Button {
                    Task { await coordinator.toggleMute() }
                } label: {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : groupVolumeIcon)
                        .font(.system(size: 14))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                Slider(value: volumeBinding, in: 0...100, step: 1)

                Text("\(coordinator.volume)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }

            // Individual member volumes (if group has multiple members)
            if let group = coordinator.selectedGroup, group.members.count > 1 {
                Divider()

                ForEach(group.members, id: \.id) { member in
                    HStack(spacing: 8) {
                        Text(member.roomName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)

                        VolumeControlView(device: member)
                    }
                }
            }
        }
    }

    private var groupVolumeIcon: String {
        if coordinator.volume == 0 { return "speaker.fill" }
        if coordinator.volume < 33 { return "speaker.wave.1.fill" }
        if coordinator.volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.volume) },
            set: { newVal in
                Task { await coordinator.setVolume(Int(newVal)) }
            }
        )
    }
}
