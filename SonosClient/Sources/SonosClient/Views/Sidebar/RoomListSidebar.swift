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
            Button("Retry") {
                coordinator.startDiscovery()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
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
