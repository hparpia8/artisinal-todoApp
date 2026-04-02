#!/usr/bin/env swift
// Generates Light, Dark, and Tinted app icon variants for macOS + iOS.
// Run from the project root: swift scripts/generate_icon.swift
//
// Layout: plain background, squircle (superellipse n=4.5).
//   – Two left-aligned rows: checkbox on left, text pill on right.
//   – Checked box: solid copper fill + white checkmark (modern iOS style).
//   – Unchecked box: thin stroke, copper-toned, no fill.

import Foundation
import CoreGraphics
import ImageIO

// ── Palette ───────────────────────────────────────────────────────────────

struct Palette {
    let background:      CGColor
    let checkedFill:     CGColor   // solid fill for the checked box
    let checkmark:       CGColor   // mark inside checked box
    let uncheckedStroke: CGColor   // stroke for the empty box
    let textLine:        CGColor   // subtle pill beside each row
}

let light = Palette(
    background:      CGColor(red: 0.973, green: 0.953, blue: 0.922, alpha: 1.000),
    checkedFill:     CGColor(red: 0.710, green: 0.435, blue: 0.178, alpha: 1.000),
    checkmark:       CGColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000),
    uncheckedStroke: CGColor(red: 0.710, green: 0.435, blue: 0.178, alpha: 0.420),
    textLine:        CGColor(red: 0.380, green: 0.345, blue: 0.305, alpha: 0.260)
)

let dark = Palette(
    background:      CGColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1.000),
    checkedFill:     CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 1.000),
    checkmark:       CGColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000),
    uncheckedStroke: CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 0.380),
    textLine:        CGColor(red: 0.478, green: 0.447, blue: 0.408, alpha: 0.320)
)

let tinted = Palette(
    background:      CGColor(red: 0, green: 0, blue: 0, alpha: 0.000),
    checkedFill:     CGColor(red: 1, green: 1, blue: 1, alpha: 1.000),
    checkmark:       CGColor(red: 0, green: 0, blue: 0, alpha: 0.600),
    uncheckedStroke: CGColor(red: 1, green: 1, blue: 1, alpha: 0.450),
    textLine:        CGColor(red: 1, green: 1, blue: 1, alpha: 0.260)
)

// ── Squircle path ─────────────────────────────────────────────────────────

func squirclePath(size: CGFloat) -> CGPath {
    let path  = CGMutablePath()
    let cx    = size / 2
    let cy    = size / 2
    let r     = size / 2
    let n: CGFloat = 4.5
    let steps = 512
    for i in 0...steps {
        let angle = CGFloat(i) * 2 * .pi / CGFloat(steps)
        let cosA  = cos(angle)
        let sinA  = sin(angle)
        let denom = pow(pow(abs(cosA), n) + pow(abs(sinA), n), 1.0 / n)
        let x = cx + r * cosA / denom
        let y = cy + r * sinA / denom
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else       { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// ── Drawing ───────────────────────────────────────────────────────────────

func makeIcon(size: Int, palette p: Palette) -> CGImage {
    let s   = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // ── Scale content to 95% (5% smaller), centered on canvas ───────────
    ctx.translateBy(x: s * 0.5, y: s * 0.5)
    ctx.scaleBy(x: 0.85, y: 0.85)
    ctx.translateBy(x: -s * 0.5, y: -s * 0.5)

    // ── Squircle clip + plain background ──────────────────────────────────
    ctx.addPath(squirclePath(size: s))
    ctx.clip()
    ctx.setFillColor(p.background)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // ── Layout ────────────────────────────────────────────────────────────
    // Apple HIG: content should fill ~80% of the icon canvas,
    // leaving ~10% safe margin on each side.
    // Row spans from 10% left to 88% right (78% width).
    // Stack spans ~64% of height, ~18% padding top/bottom.

    let bs      = s * 0.285             // box side
    let gap     = s * 0.072             // gap between rows
    let lw      = max(1.0, s * 0.018)  // stroke — thin and refined
    let cr      = bs * 0.22             // slightly rounder corners = modern feel

    let tlH     = s * 0.026
    let tl1W    = s * 0.420             // checked row pill (shorter)
    let tl2W    = s * 0.475             // unchecked row pill
    let tlCR    = tlH * 0.5
    let itemGap = s * 0.025

    let rowX       = s * 0.100
    let totalH     = bs * 2 + gap
    let stackBottom = (s - totalH) / 2

    let uncheckedY = stackBottom
    let checkedY   = stackBottom + bs + gap

    // ── Checked box — solid fill + white checkmark ────────────────────────
    let checkedRect = CGRect(x: rowX, y: checkedY, width: bs, height: bs)
    let checkedPath = CGPath(roundedRect: checkedRect,
                             cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.setFillColor(p.checkedFill)
    ctx.addPath(checkedPath); ctx.fillPath()

    // White checkmark — clean, precise V
    let cmLW = max(1.5, s * 0.030)
    ctx.setStrokeColor(p.checkmark)
    ctx.setLineWidth(cmLW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to:    CGPoint(x: rowX + bs * 0.22, y: checkedY + bs * 0.50))
    ctx.addLine(to: CGPoint(x: rowX + bs * 0.43, y: checkedY + bs * 0.28))
    ctx.addLine(to: CGPoint(x: rowX + bs * 0.78, y: checkedY + bs * 0.70))
    ctx.strokePath()

    // Text pill
    if size >= 32 {
        let tlY = checkedY + (bs - tlH) / 2
        let r1  = CGRect(x: rowX + bs + itemGap, y: tlY, width: tl1W, height: tlH)
        ctx.setFillColor(p.textLine)
        ctx.addPath(CGPath(roundedRect: r1, cornerWidth: tlCR, cornerHeight: tlCR, transform: nil))
        ctx.fillPath()
    }

    // ── Unchecked box — thin copper-tinted stroke, no fill ────────────────
    let uncheckedRect = CGRect(x: rowX, y: uncheckedY, width: bs, height: bs)
    let uncheckedPath = CGPath(roundedRect: uncheckedRect,
                               cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.setStrokeColor(p.uncheckedStroke)
    ctx.setLineWidth(lw)
    ctx.addPath(uncheckedPath); ctx.strokePath()

    // Text pill
    if size >= 32 {
        let tlY = uncheckedY + (bs - tlH) / 2
        let r2  = CGRect(x: rowX + bs + itemGap, y: tlY, width: tl2W, height: tlH)
        ctx.setFillColor(p.textLine)
        ctx.addPath(CGPath(roundedRect: r2, cornerWidth: tlCR, cornerHeight: tlCR, transform: nil))
        ctx.fillPath()
    }

    return ctx.makeImage()!
}

// ── PNG output ────────────────────────────────────────────────────────────

func savePNG(_ img: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// ── Main ──────────────────────────────────────────────────────────────────

let root       = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent("TodoApp/Assets.xcassets/AppIcon.appiconset")
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let macSizes   = [16, 32, 64, 128, 256, 512, 1024]
let variants: [(String, Palette)] = [("light", light), ("dark", dark), ("tinted", tinted)]

for (name, palette) in variants {
    let sizes = (name == "tinted") ? [1024] : macSizes
    for sz in sizes {
        let url = iconsetDir.appendingPathComponent("icon_\(name)_\(sz).png")
        savePNG(makeIcon(size: sz, palette: palette), to: url)
        print("  ✓ \(name)  \(sz)×\(sz)")
    }
}

print("\nDone → \(iconsetDir.path)")
