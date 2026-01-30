import SwiftUI

/// Global keyboard shortcut handling for media controls.
struct KeyboardShortcutModifier: ViewModifier {
    @EnvironmentObject var coordinator: SonosCoordinator

    func body(content: Content) -> some View {
        content
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleKeyEvent(event)
                }
            }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Media keys are handled by the system, but we can handle custom shortcuts
        switch event.keyCode {
        case 49: // Space (handled via .keyboardShortcut in button)
            return event
        default:
            return event
        }
    }
}

extension View {
    func withKeyboardShortcuts() -> some View {
        modifier(KeyboardShortcutModifier())
    }
}
