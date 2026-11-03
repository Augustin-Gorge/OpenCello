// Harness CLI : listing + téléchargement d'un PDF IMSLP via le moteur de
// l'app (IMSLPClient), comme les autres tests du projet.
//
// Compilation (depuis la racine du dépôt) :
//   swiftc -O -o build/qa/imslp_download \
//     OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
//     tools/qa/imslp_download_test.swift
//   ./build/qa/imslp_download
//
// Vérifie : listing de la page BWV 1007 (métadonnées + statuts de copyright),
// puis téléchargement complet d'un fichier domaine public (BWV1007.pdf,
// Bach-Gesellschaft 1879) avec signature %PDF et cohérence de taille.

import Foundation

@main
struct IMSLPDownloadTest {
    static func main() async {
        let client = IMSLPClient()
        let pageTitle = "Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)"

        do {
            let files = try await client.listScoreFiles(pageTitle: pageTitle)
            print("Liste : \(files.count) PDF sur la page")
            for file in files.prefix(8) {
                let index = file.index.map(String.init) ?? "?"
                let badge = file.isPublicDomain ? "DOMAINE PUBLIC"
                    : (file.copyright.isEmpty ? "?" : file.copyright)
                print("  [\(index)] \(file.name) | \(badge)")
            }

            guard let target = files.first(where: { $0.name == "BWV1007.pdf" }),
                  let index = target.index else {
                print("ÉCHEC : BWV1007.pdf introuvable ou sans index")
                exit(1)
            }
            guard target.isPublicDomain else {
                print("ÉCHEC : \(target.name) n'est pas domaine public (\(target.copyright))")
                exit(1)
            }

            print("Téléchargement de \(target.name) (index \(index))…")
            let data = try await client.downloadScoreFile(index: index)
            let destination = "build/qa/bwv1007_via_moteur.pdf"
            try data.write(to: URL(fileURLWithPath: destination))
            let signature = String(decoding: data.prefix(5), as: UTF8.self)
            print("Fichier : \(destination) | \(data.count) octets | \(signature)")
            exit(signature == "%PDF-" ? 0 : 2)
        } catch {
            print("ERREUR : \(error.localizedDescription)")
            exit(3)
        }
    }
}
