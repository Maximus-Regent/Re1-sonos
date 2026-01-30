import SwiftUI

@main
struct SonosClientApp: App {
    @StateObject private var coordinator = SonosCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    coordinator.startDiscovery()
                }
                .onDisappear {
                    coordinator.stopAll()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Devices") {
                    coordinator.startDiscovery()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
        #endif
    }
}
