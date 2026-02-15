import SwiftUI

/// Input source switcher for devices with TV/line-in inputs.
struct InputSwitcherView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        let device = coordinator.selectedGroup?.coordinator

        if let device = device, device.hasExternalInput {
            HStack(spacing: 8) {
                // Queue button
                inputButton(
                    title: "Queue",
                    icon: "list.bullet",
                    isActive: coordinator.currentInputSource == .queue
                ) {
                    Task { await coordinator.switchToQueue() }
                }

                if device.hasLineIn {
                    inputButton(
                        title: "Line-In",
                        icon: "cable.connector",
                        isActive: coordinator.currentInputSource == .lineIn
                    ) {
                        Task { await coordinator.switchToLineIn() }
                    }
                }

                if device.hasTVInput {
                    inputButton(
                        title: "TV",
                        icon: "tv",
                        isActive: coordinator.currentInputSource == .tvInput
                    ) {
                        Task { await coordinator.switchToTVInput() }
                    }
                }
            }
        }
    }

    private func inputButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            )
            .foregroundColor(isActive ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
