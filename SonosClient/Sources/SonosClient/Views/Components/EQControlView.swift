import SwiftUI

/// Bass and treble EQ sliders with reset button.
struct EQControlView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Text("Equalizer")
                .font(.system(size: 14, weight: .semibold))

            // Bass
            VStack(spacing: 4) {
                HStack {
                    Text("Bass")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(coordinator.bass)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: bassBinding,
                    in: -10...10,
                    step: 1
                )
                .controlSize(.small)
            }

            // Treble
            VStack(spacing: 4) {
                HStack {
                    Text("Treble")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(coordinator.treble)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: trebleBinding,
                    in: -10...10,
                    step: 1
                )
                .controlSize(.small)
            }

            // Reset button
            Button("Reset") {
                Task {
                    await coordinator.setBass(0)
                    await coordinator.setTreble(0)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(coordinator.bass == 0 && coordinator.treble == 0)
        }
        .padding(16)
        .frame(width: 220)
    }

    private var bassBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.bass) },
            set: { newVal in Task { await coordinator.setBass(Int(newVal)) } }
        )
    }

    private var trebleBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.treble) },
            set: { newVal in Task { await coordinator.setTreble(Int(newVal)) } }
        )
    }
}
