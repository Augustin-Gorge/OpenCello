import Foundation

@main
struct FuzzyTest {
    static func main() async {
        do {
            _ = try await IMSLPClient.shared.loadComposerIndex()
            let queries = [
                "alleggro appassionato Saint Saens",
                "alleggro",
                "apasionnato Saint Saens",
                "apasionnato",
                "appasionato Saint Saens",
                "allegro appassionato Saint Saens"
            ]
            for query in queries {
                let outcome = try await IMSLPClient.shared.searchWorks(query: query, limit: 6)
                print("\nQUERY:", query)
                print("  composer:", outcome.composerSurname ?? "-", "| results:", outcome.works.count)
                for work in outcome.works.prefix(3) {
                    print("   -", work.title)
                }
            }
        } catch {
            print("ERROR:", error)
            exit(1)
        }
    }
}
