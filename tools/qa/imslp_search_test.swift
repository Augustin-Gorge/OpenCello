import Foundation

@main
struct IMSLPTest {
    static func main() async {
        do {
            let started = Date()
            let index = try await IMSLPClient.shared.loadComposerIndex()
            print("COMPOSERS:", index.count, "loaded in", String(format: "%.1f", Date().timeIntervalSince(started)), "s")

            print("\nPLAN pour « Allegro appasionato Saint Saens » :")
            for line in IMSLPClient.shared.debugPlan(for: "Allegro appasionato Saint Saens") {
                print("  ", line)
            }

            let direct = try await IMSLPClient.shared.searchWorks(query: "Saint-Saëns allegro appassionato", limit: 10)
            print("\nDIRECT composer+work:", direct.works.count, "results")
            for work in direct.works.prefix(6) { print("  -", work.title) }

            let queries = [
                "Allegro appasionato Saint Saens",
                "allegro apasionato",
                "saint saens",
                "bach suite cello",
                "sevcik",
                "dvorak"
            ]

            for query in queries {
                let outcome = try await IMSLPClient.shared.searchWorks(query: query, limit: 8)
                print("\nQUERY:", query)
                print("composer:", outcome.composerSurname ?? "-",
                      "| fallback:", outcome.usedFallback,
                      "| results:", outcome.works.count)
                for work in outcome.works.prefix(4) {
                    print("  -", work.title)
                }
            }
        } catch {
            print("ERROR:", error)
            exit(1)
        }
    }
}
