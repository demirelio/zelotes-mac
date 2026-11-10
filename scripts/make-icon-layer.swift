import AppKit
import CoreGraphics

// Makes the mouse layer of the app icon (Support/AppIcon.icon/Assets/Mouse.png) from the finger-side photo:
// the mouse centered on a transparent 1024-point canvas, with the cable faded out below the body.
// Run from the repository root: swift scripts/make-icon-layer.swift

let canvas = 1024
/// Height of the mouse body, cable excluded, as a fraction of the canvas.
let bodyHeight = 0.76
/// Where the cable leaves the body, as a fraction of the photo's height from the top, and how far it fades.
let cableStart = 0.885
let cableFade = 0.035

let photoURL = URL(fileURLWithPath: "Support/c18-finger.png")
let layerURL = URL(fileURLWithPath: "Support/AppIcon.icon/Assets/Mouse.png")

guard let photo = NSImage(contentsOf: photoURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Run this from the repository root; \(photoURL.path) was not found")
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func makeContext() -> CGContext {
    CGContext(
        data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

let side = Double(canvas)
let scale = side * bodyHeight / (Double(photo.height) * cableStart)
let drawn = CGSize(width: Double(photo.width) * scale, height: Double(photo.height) * scale)
// Core Graphics counts from the bottom: the body's top edge goes as far above the middle as its bottom goes below.
let bodyTop = side / 2 + side * bodyHeight / 2
let frame = CGRect(x: (side - drawn.width) / 2, y: bodyTop - drawn.height, width: drawn.width, height: drawn.height)

let mask = makeContext()
let fade = CGGradient(
    colorsSpace: colorSpace,
    colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray,
    locations: [0, 1]
)!
mask.drawLinearGradient(
    fade,
    start: CGPoint(x: 0, y: frame.minY + drawn.height * (1 - cableStart + cableFade)),
    end: CGPoint(x: 0, y: frame.minY + drawn.height * (1 - cableStart)),
    options: [.drawsBeforeStartLocation]
)

let layer = makeContext()
layer.interpolationQuality = .high
layer.clip(to: CGRect(x: 0, y: 0, width: side, height: side), mask: mask.makeImage()!)
layer.draw(photo, in: frame)

let png = NSBitmapImageRep(cgImage: layer.makeImage()!).representation(using: .png, properties: [:])!
try FileManager.default.createDirectory(at: layerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: layerURL)
print("Wrote \(layerURL.path)")
