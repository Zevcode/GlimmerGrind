// Renders AppIcon.icns from code — no image assets in the repo.
// An engram core over an ember-lit graphite plate, sized to read at 16pt.
//
//   swift Tools/make-icon.swift <output.icns>

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let hex: (UInt32) -> (Double, Double, Double) = { h in
    (Double((h >> 16) & 0xFF) / 255, Double((h >> 8) & 0xFF) / 255, Double(h & 0xFF) / 255)
}

func makeImage(side: Int) -> CGImage? {
    let s = Double(side)
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Big Sur proportions: the plate sits inside a transparent margin.
    let inset = s * 0.086
    let plate = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = plate.width * 0.2237

    let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Graphite body, lit warm from the top.
    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()

    let bodyTop = hex(0x2E2528), bodyBottom = hex(0x0C0B0C)
    if let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: bodyTop.0, green: bodyTop.1, blue: bodyTop.2, alpha: 1),
            CGColor(red: bodyBottom.0, green: bodyBottom.1, blue: bodyBottom.2, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
    }

    // Ember glow rising from beneath the engram.
    let ember = hex(0xD8441A)
    if let glow = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: ember.0, green: ember.1, blue: ember.2, alpha: 0.85),
            CGColor(red: ember.0, green: ember.1, blue: ember.2, alpha: 0)
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(glow,
                               startCenter: CGPoint(x: s / 2, y: s * 0.40), startRadius: 0,
                               endCenter: CGPoint(x: s / 2, y: s * 0.40), endRadius: s * 0.42,
                               options: [])
    }
    ctx.restoreGState()

    // Engram: three nested facets, brightest at the core.
    func engram(_ scale: Double) -> CGPath {
        let cx = s / 2, cy = s * 0.5
        let r = s * 0.30 * scale
        let path = CGMutablePath()
        // Flat-top hexagon, slightly tall — the engram silhouette.
        let points: [(Double, Double)] = [
            (0, 1.06), (0.92, 0.53), (0.92, -0.53), (0, -1.06), (-0.92, -0.53), (-0.92, 0.53)
        ]
        for (i, p) in points.enumerated() {
            let point = CGPoint(x: cx + p.0 * r, y: cy + p.1 * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    let gold = hex(0xFFC46B), solar = hex(0xFF8A3D)

    ctx.addPath(engram(1.0))
    ctx.setFillColor(CGColor(red: gold.0, green: gold.1, blue: gold.2, alpha: 0.26))
    ctx.fillPath()

    ctx.addPath(engram(0.66))
    ctx.setFillColor(CGColor(red: solar.0, green: solar.1, blue: solar.2, alpha: 0.85))
    ctx.fillPath()

    ctx.addPath(engram(0.34))
    ctx.setFillColor(CGColor(red: gold.0, green: gold.1, blue: gold.2, alpha: 1))
    ctx.fillPath()

    // Hairline so the plate keeps its edge on a light desktop.
    ctx.addPath(platePath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(max(1, s * 0.004))
    ctx.strokePath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot write \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - main

let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "AppIcon.icns")

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("GlimmerGrind.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// (base point size, scale) → the filenames iconutil expects.
let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2),
                              (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

for (base, scale) in variants {
    let pixels = base * scale
    guard let image = makeImage(side: pixels) else { continue }
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    write(image, to: iconset.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✓ wrote \(output.lastPathComponent)")
} else {
    print("✗ iconutil failed (\(task.terminationStatus))")
    exit(1)
}
