// pdf_render.swift — Rend chaque page d'un PDF en PNG (PDFKit, zéro dépendance externe).
//
// Utilisé par le pipeline OMR (docs/18) : l'app ne stocke jamais le PDF ;
// seules les images de pages sont rendues localement pour la transcription.
//
// Usage : pdf_render <input.pdf> <output_dir> [dpi=200]
// Sortie : page-001.png, page-002.png, … + un résumé sur stdout.

import Foundation
import PDFKit
import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("Usage : pdf_render <input.pdf> <output_dir> [dpi=200]")
}
let inputPath = args[1]
let outputDir = args[2]
let dpi = args.count >= 4 ? (Double(args[3]) ?? 200) : 200

guard let pdf = PDFDocument(url: URL(fileURLWithPath: inputPath)) else {
    fail("Impossible d'ouvrir le PDF : \(inputPath)")
}
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let pageCount = pdf.pageCount
var rendered = 0
for index in 0..<pageCount {
    guard let page = pdf.page(at: index) else { continue }
    let mediaBox = page.bounds(for: .mediaBox)
    guard mediaBox.width > 0, mediaBox.height > 0 else { continue }
    let scale = dpi / 72.0
    let width = max(1, Int(mediaBox.width * scale))
    let height = max(1, Int(mediaBox.height * scale))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("Impossible de créer le contexte graphique.")
    }
    // Fond blanc (indispensable pour les PDF transparents/scannés)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    guard let image = context.makeImage() else { continue }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    let name = String(format: "page-%03d.png", index + 1)
    do {
        try png.write(to: URL(fileURLWithPath: outputDir + "/" + name))
        rendered += 1
    } catch {
        FileHandle.standardError.write(("Échec d'écriture de \(name) : \(error)\n").data(using: .utf8)!)
    }
}
print("\(rendered)/\(pageCount) pages rendues dans \(outputDir) à \(Int(dpi)) dpi")
