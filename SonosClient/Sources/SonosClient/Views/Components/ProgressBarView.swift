import SwiftUI

/// Seekable progress bar with time labels.
struct ProgressBarView: View {
    let currentPosition: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragPosition: TimeInterval = 0

    private var displayPosition: TimeInterval {
        isDragging ? dragPosition : currentPosition
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, displayPosition / duration))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Seek bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress, height: 4)

                    // Thumb (visible on hover/drag)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .offset(x: geo.size.width * progress - 6)
                        .opacity(isDragging ? 1 : 0)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            dragPosition = fraction * duration
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            let target = fraction * duration
                            onSeek(target)
                            isDragging = false
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .frame(height: 12)

            // Time labels
            HStack {
                Text(XMLHelper.formatDuration(displayPosition))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(XMLHelper.formatDuration(duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}
