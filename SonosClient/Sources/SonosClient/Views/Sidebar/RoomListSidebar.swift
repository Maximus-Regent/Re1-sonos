import SwiftUI

/// Lists discovered Sonos groups/rooms in the sidebar for quick selection.
struct RoomListSidebar: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if coordinator.groups.isEmpty && !coordinator.isDiscovering {
                    emptyState
                } else {
                    ForEach(coordinator.groups) { group in
                        RoomRow(group: group, isSelected: coordinator.selectedGroup?.id == group.id)
                            .onTapGesture {
                                coordinator.selectGroup(group)
                            }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No rooms found")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Retry Discovery") {
                coordinator.startDiscovery()
            }
            .controlSize(.small)

            // Compact manual IP entry in sidebar
            ManualIPEntrySidebar()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// Compact manual IP entry for the sidebar.
struct ManualIPEntrySidebar: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var ip: String = ""
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 4) {
            Text("Add by IP")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                TextField("IP address", text: $ip)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit { add() }
                Button {
                    add()
                } label: {
                    if isAdding {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.plain)
                .disabled(ip.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
        }
        .padding(.horizontal, 8)
    }

    private func add() {
        isAdding = true
        Task {
            await coordinator.addDeviceManually(ip: ip)
            isAdding = false
        }
    }
}

struct RoomRow: View {
    let group: SonosGroup
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.coordinator.icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                if group.members.count > 1 {
                    Text("\(group.members.count) speakers")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Volume indicator
            Text("\(group.volume)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
