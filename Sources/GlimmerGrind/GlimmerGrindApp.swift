import SwiftUI

@main
struct GlimmerGrindApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1320, height: 840)
        .windowResizability(.contentMinSize)
        #endif
    }
}
