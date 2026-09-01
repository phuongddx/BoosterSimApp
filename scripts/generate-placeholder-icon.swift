#!/usr/bin/env swift
//
// BoosterSimApp PLACEHOLDER app-icon generator (07-04 Path B).
//
// Composes, at each of the 10 exact AppIcon pixel sizes, a full-bleed
// amber canvas (#E8720C, the light-mode accent from
// docs/design-guidelines.md) with a centered white SF Symbol
// "bolt.fill" fitted to ~55% of the canvas, written as an opaque sRGB
// PNG into BoosterSimApp/Assets.xcassets/AppIcon.appiconset/.
//
// Why full-bleed and not a pre-rounded square: macOS masks AppIcon
// art with its own continuous-curvature squircle (~22.5% effective
// radius) at display time. Shipping square art lets the system render
// the true "macOS-style continuous look"; a bezier-rounded PNG would
// both approximate the curvature with circular arcs and force
// non-opaque corners. (Apple's current macOS icon guidance: provide
// square art, don't pre-round.)
//
// The hex value lives in this seeding script the same way it lives in
// the AccentColor asset — app-code design-token rules don't apply to
// the asset generator.
//
// This output is a PLACEHOLDER pending real design, never finished art.
//
// Usage: swift scripts/generate-placeholder-icon.swift [output-dir]
// Offscreen only: NSBitmapImageRep + NSGraphicsContext — no window
// server needed.

import AppKit

// MARK: - Configuration

/// Light-mode amber accent (#E8720C) from docs/design-guidelines.md.
let amber = NSColor(srgbRed: 0xE8 / 255.0, green: 0x72 / 255.0,
                    blue: 0x0C / 255.0, alpha: 1.0)

/// Symbol fitted to this fraction of the canvas (longest side).
let symbolScale = 0.55

/// The 10 declared AppIcon entries (Contents.json order) -> filename + exact pixels.
let outputs: [(filename: String, pixels: Int)] = [
    ("icon-16.png", 16),
    ("icon-16@2x.png", 32),
    ("icon-32.png", 32),
    ("icon-32@2x.png", 64),
    ("icon-128.png", 128),
    ("icon-128@2x.png", 256),
    ("icon-256.png", 256),
    ("icon-256@2x.png", 512),
    ("icon-512.png", 512),
    ("icon-512@2x.png", 1024),
]

// Output directory: argument override, else derived from this file's
// location so the script works from any cwd.
let outputDir: URL
if CommandLine.arguments.count > 1 {
    outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
} else {
    let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent()
    outputDir = repoRoot
        .appendingPathComponent("BoosterSimApp/Assets.xcassets/AppIcon.appiconset")
}

// MARK: - Rendering
func makeRep(_ pixels: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    // deviceRGB (no ICC tag on this SDK's get-only colorSpace API); colors
    // below are authored via NSColor(srgbRed:) so the stored components are
    // the sRGB values (#E8720C -> 232,114,12).
}

/// Runs `body` with `rep` as the current graphics context; restores after.
func withContext<T>(_ rep: NSBitmapImageRep, _ body: () throws -> T) throws -> T {
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw GenError.contextCreationFailed(rep.pixelsWide)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer {
        NSGraphicsContext.current = nil
        NSGraphicsContext.restoreGraphicsState()
    }
    return try body()
}

func renderIcon(pixels: Int) throws -> NSBitmapImageRep {
    // Layer 1 (transparent): the SF Symbol. Template symbols render as
    // ink+alpha regardless of the context fill color, so recolor via a
    // .sourceIn white fill — alpha survives, color becomes white.
    guard let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) else {
        throw GenError.symbolUnavailable
    }
    let layer = makeRep(pixels)
    try withContext(layer) {
        let box = CGFloat(pixels) * CGFloat(symbolScale)
        let fit = min(box / max(symbol.size.width, 1), box / max(symbol.size.height, 1))
        let drawSize = NSSize(width: symbol.size.width * fit, height: symbol.size.height * fit)
        let rect = NSRect(
            x: (CGFloat(pixels) - drawSize.width) / 2,
            y: (CGFloat(pixels) - drawSize.height) / 2,
            width: drawSize.width, height: drawSize.height)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0,
                    respectFlipped: false, hints: nil)
        NSColor.white.setFill()
        rect.fill(using: .sourceIn)
    }

    // Layer 2 (canvas): full-bleed amber + white bolt composite.
    let canvas = makeRep(pixels)
    try withContext(canvas) {
        amber.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: pixels, height: pixels)).fill()
        guard let tiff = layer.tiffRepresentation,
              let layerImage = NSImage(data: tiff) else {
            throw GenError.pngEncodingFailed("layer composite at \(pixels)px")
        }
        layerImage.draw(
            in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
            from: .zero, operation: .sourceOver, fraction: 1.0,
            respectFlipped: false, hints: nil)
    }
    return canvas
}

/// Coarse-grid sanity check: the render must contain amber and white
/// pixels (catches a silently-failed symbol render or tint).
func verifyRender(_ rep: NSBitmapImageRep, pixels: Int) throws {
    let step = max(1, pixels / 32)
    var amberish = 0, whitish = 0
    for y in stride(from: 0, to: pixels, by: step) {
        for x in stride(from: 0, to: pixels, by: step) {
            guard let c = rep.colorAt(x: x, y: y) else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            if r > 0.85, g > 0.40, g < 0.60, b < 0.20 { amberish += 1 }
            if r > 0.92, g > 0.92, b > 0.92 { whitish += 1 }
        }
    }
    guard amberish > 0 else { throw GenError.noAmberPixels(pixels) }
    guard whitish > 0 else { throw GenError.noWhiteSymbolPixels(pixels) }
}

// MARK: - Main

enum GenError: Error, CustomStringConvertible {
    case contextCreationFailed(Int)
    case symbolUnavailable
    case noAmberPixels(Int)
    case noWhiteSymbolPixels(Int)
    case pngEncodingFailed(String)

    var description: String {
        switch self {
        case .contextCreationFailed(let p): return "failed to create bitmap context at \(p)px"
        case .symbolUnavailable: return "SF Symbol bolt.fill unavailable"
        case .noAmberPixels(let p): return "no amber pixels at \(p)px — canvas render failed"
        case .noWhiteSymbolPixels(let p): return "no white pixels at \(p)px — symbol render/tint failed"
        case .pngEncodingFailed(let f): return "PNG encoding failed for \(f)"
        }
    }
}

do {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    for output in outputs {
        let rep = try renderIcon(pixels: output.pixels)
        try verifyRender(rep, pixels: output.pixels)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw GenError.pngEncodingFailed(output.filename)
        }
        try png.write(to: outputDir.appendingPathComponent(output.filename))
        print("wrote \(output.filename) (\(output.pixels)x\(output.pixels))")
    }
    print("done: \(outputs.count) placeholder icons in \(outputDir.path)")
} catch {
    FileHandle.standardError.write("generate-placeholder-icon: FAIL — \(error)\n".data(using: .utf8)!)
    exit(1)
}
