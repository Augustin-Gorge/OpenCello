import SwiftUI

@main
struct OpenCelloApp: App {
    @StateObject private var engine = SessionEngine()

    var body: some Scene {
        WindowGroup("OpenCello") {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}
