import SwiftUI

/// Sleep timer presets and active countdown display.
struct SleepTimerView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    private let presets = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 12) {
            Text("Sleep Timer")
                .font(.system(size: 14, weight: .semibold))

            if let remaining = coordinator.sleepTimerRemaining {
                // Active timer display
                VStack(spacing: 8) {
                    Text(formatCountdown(remaining))
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundColor(.accentColor)

                    Text("remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button("Cancel Timer") {
                        Task { await coordinator.cancelSleepTimer() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                // Preset grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        Button {
                            Task { await coordinator.setSleepTimer(minutes: minutes) }
                        } label: {
                            Text(formatPreset(minutes))
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    private func formatPreset(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
