import SwiftUI

@main
struct VertexApp: App {
    init() {
        PairingController.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
