// pdf_page.swift — Extrait une page d'un PDF dans un nouveau PDF (PDFKit).
//
// Usage : Build/qa/pdf_page <source.pdf> <destination.pdf> <numéro 1-based>
// Utilisé par les tests OMR (docs/18) pour borner les coûts : la transcription
// IA porte sur une page unique, comparable page à page avec Audiveris.

import Foundation
import PDFKit

guard CommandLine.arguments.count == 4,
      let index = Int(CommandLine.arguments[3]), index >= 1,
      let source = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])),
      let page = source.page(at: index - 1) else {
    fputs("Usage : pdf_page <source.pdf> <destination.pdf> <numéro de page 1-based>\n", stderr)
    exit(2)
}

let output = PDFDocument()
output.insert(page, at: 0)
if output.write(to: URL(fileURLWithPath: CommandLine.arguments[2])) {
    print("Page \(index)/\(source.pageCount) extraite → \(CommandLine.arguments[2])")
} else {
    fputs("Échec d'écriture de \(CommandLine.arguments[2])\n", stderr)
    exit(1)
}
