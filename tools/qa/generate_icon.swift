import AppKit
import Foundation

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Impossible de créer le bitmap")
}

NSGraphicsContext.saveGraphicsState()
if let context = NSGraphicsContext(bitmapImageRep: rep) {
    NSGraphicsContext.current = context
}

let background = NSBezierPath(
    roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960),
    xRadius: 210,
    yRadius: 210
)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.32, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.09, alpha: 1)
])
gradient?.draw(in: background, angle: -90)

NSColor(white: 1, alpha: 0.08).setStroke()
background.lineWidth = 5
background.stroke()

// Corps du violoncelle
let bodyColor = NSColor(calibratedRed: 0.79, green: 0.53, blue: 0.27, alpha: 1)
let bodyStroke = NSColor(calibratedRed: 0.34, green: 0.19, blue: 0.08, alpha: 1)

bodyColor.setFill()
let lowerBout = NSBezierPath(ovalIn: NSRect(x: 392, y: 178, width: 264, height: 310))
let upperBout = NSBezierPath(ovalIn: NSRect(x: 420, y: 430, width: 208, height: 216))
lowerBout.fill()
upperBout.fill()

bodyStroke.setStroke()
lowerBout.lineWidth = 6
upperBout.lineWidth = 6
lowerBout.stroke()
upperBout.stroke()

// Manche et tête
let neckColor = NSColor(calibratedRed: 0.46, green: 0.28, blue: 0.13, alpha: 1)
neckColor.setFill()
NSBezierPath(rect: NSRect(x: 512, y: 610, width: 28, height: 260)).fill()
NSBezierPath(ovalIn: NSRect(x: 486, y: 846, width: 80, height: 80)).fill()

// Cordes
NSColor(calibratedRed: 0.96, green: 0.91, blue: 0.76, alpha: 0.9).setStroke()
for offset in [-20.0, -7.0, 7.0, 20.0] {
    let string = NSBezierPath()
    string.move(to: NSPoint(x: 526 + offset, y: 228))
    string.line(to: NSPoint(x: 526 + offset * 0.35, y: 848))
    string.lineWidth = 2.5
    string.stroke()
}

// Chevalet
NSColor(calibratedRed: 0.30, green: 0.17, blue: 0.07, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 478, y: 222, width: 96, height: 13)).fill()

// Ouïes
bodyStroke.setStroke()
for x in [462.0, 578.0] {
    let fHole = NSBezierPath()
    fHole.move(to: NSPoint(x: x, y: 400))
    fHole.curve(
        to: NSPoint(x: x, y: 326),
        controlPoint1: NSPoint(x: x - 26, y: 392),
        controlPoint2: NSPoint(x: x - 26, y: 336)
    )
    fHole.lineWidth = 9
    fHole.stroke()
}

// Archet
let bow = NSBezierPath()
bow.move(to: NSPoint(x: 246, y: 786))
bow.line(to: NSPoint(x: 806, y: 258))
bow.lineWidth = 11
NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.80, alpha: 0.95).setStroke()
bow.stroke()

let hair = NSBezierPath()
hair.move(to: NSPoint(x: 268, y: 750))
hair.line(to: NSPoint(x: 784, y: 286))
hair.lineWidth = 3
NSColor(white: 1, alpha: 0.45).setStroke()
hair.stroke()

// Accent doré
NSColor(calibratedRed: 0.92, green: 0.76, blue: 0.38, alpha: 0.9).setFill()
NSBezierPath(ovalIn: NSRect(x: 496, y: 856, width: 60, height: 60)).fill()

NSGraphicsContext.restoreGraphicsState()

let directory = URL(fileURLWithPath: "OpenCello/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

let source = NSImage(size: NSSize(width: 1024, height: 1024))
source.addRepresentation(rep)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, pixelSize) in outputs {
    guard let target = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { continue }

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: target) {
        NSGraphicsContext.current = context
    }
    source.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let png = target.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: directory.appendingPathComponent(filename))
    print("Icône \(filename) (\(pixelSize)px)")
}

