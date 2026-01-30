import SwiftUI

/// Full room management view: see all devices, group/ungroup speakers.
struct RoomManagementView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var selectedDeviceForGrouping: SonosDevice?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rooms & Groups")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button {
                    coordinator.startDiscovery()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(coordinator.isDiscovering)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Groups
                    ForEach(coordinator.groups) { group in
                        GroupCard(group: group, onSelectDevice: { device in
                            selectedDeviceForGrouping = device
                        })
                    }

                    // Standalone devices not in any group
                    let groupedIds = Set(coordinator.groups.flatMap { $0.members.map(\.id) })
                    let ungrouped = coordinator.devices.filter { !groupedIds.contains($0.id) }
                    if !ungrouped.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ungrouped")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(ungrouped, id: \.id) { device in
                                DeviceRow(device: device)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $selectedDeviceForGrouping) { device in
            GroupingSheet(device: device, groups: coordinator.groups) { coordinator in
                selectedDeviceForGrouping = nil
                Task { await coordinator.refreshGroups() }
            }
            .environmentObject(coordinator)
        }
    }
}

struct GroupCard: View {
    let group: SonosGroup
    let onSelectDevice: (SonosDevice) -> Void
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Group header
            HStack {
                Image(systemName: group.members.count > 1 ? "rectangle.stack.fill" : group.coordinator.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)

                Text(group.displayName)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                // Play on this group
                Button {
                    coordinator.selectGroup(group)
                } label: {
                    Text("Select")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            // Members
            ForEach(group.members, id: \.id) { member in
                HStack(spacing: 8) {
                    Image(systemName: member.icon)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(member.roomName)
                            .font(.system(size: 13))
                        Text("\(member.modelName)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if member.id == group.coordinator.id {
                        Text("Coordinator")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }

                    if group.members.count > 1 && member.id != group.coordinator.id {
                        Button("Ungroup") {
                            Task { await coordinator.ungroupDevice(member) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    coordinator.selectedGroup?.id == group.id ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

struct DeviceRow: View {
    let device: SonosDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.roomName)
                    .font(.system(size: 13))
                Text("\(device.modelName) - \(device.ip)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// SonosDevice already conforms to Identifiable

struct GroupingSheet: View {
    let device: SonosDevice
    let groups: [SonosGroup]
    let onDone: (SonosCoordinator) -> Void
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Text("Group \(device.roomName)")
                .font(.headline)

            Text("Select a group to join:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(groups) { group in
                Button {
                    Task {
                        await coordinator.groupDevices(device, with: group.coordinator)
                        onDone(coordinator)
                    }
                } label: {
                    HStack {
                        Image(systemName: group.coordinator.icon)
                        Text(group.displayName)
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Cancel") {
                onDone(coordinator)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 320, height: 300)
    }
}
