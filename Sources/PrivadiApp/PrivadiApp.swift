import PrivadiCore
import SwiftUI

@main
struct PrivadiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(environment: .liveApp())
        }
    }
}
