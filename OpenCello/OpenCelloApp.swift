import SwiftUI

@main
struct OpenCelloApp: App {
    @StateObject private var engine = SessionEngine()

    var body: some Scene {
        WindowGroup("OpenCello") {
            #if DEBUG
            if let url = Self.debugStudioURL {
                ScoreStudioView(url: url)
                    .frame(minWidth: 1_000, minHeight: 700)
            } else {
                ContentView()
                    .environmentObject(engine)
                    .frame(minWidth: 980, minHeight: 640)
            }
            #else
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 980, minHeight: 640)
            #endif
        }
        .windowResizability(.contentMinSize)
    }

    #if DEBUG
    /// Point d'entrée de test : `OpenCello.app --args --score-studio <fichier.musicxml>`.
    private static var debugStudioURL: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--score-studio"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return URL(fileURLWithPath: arguments[index + 1])
    }
    #endif
}
