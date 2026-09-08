import SwiftUI

@main
struct GlimmerGrindApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1320, height: 840)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}
