import SwiftUI
import PrivadiCore

@main
struct PrivadiIOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(environment: .liveApp())
        }
    }
}
