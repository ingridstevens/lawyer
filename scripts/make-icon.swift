// Draws the app icon: a § in stamp blue on a white sheet, over a highlighter stroke.
// Usage: swift scripts/make-icon.swift <out.png>   (writes a 1024 × 1024 PNG)
import AppKit
import CoreText

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// macOS icon grid: an 824 pt rounded square centred on the 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.25))
ctx.addPath(shape); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()
let paper = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF), color(0xE9ECF2)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(paper, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// The section sign, from the glyph outline so it can be centred exactly.
let font = CTFontCreateWithName("DINCondensed-Bold" as CFString, 640, nil)
var chars: [UniChar] = Array("§".utf16)
var glyph = CGGlyph(0)
CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1)
let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil)!
let gb = glyphPath.boundingBoxOfPath
var place = CGAffineTransform(translationX: 512 - gb.midX, y: 512 - gb.midY)
let placed = glyphPath.copy(using: &place)!

// Highlighter: a slanted band behind the middle of the sign, with chisel-cut ends,
// multiplied onto the paper like real marker ink.
ctx.saveGState()
ctx.translateBy(x: 512, y: 500)
ctx.rotate(by: 8 * .pi / 180)
let band = CGMutablePath()
band.move(to: CGPoint(x: -318, y: -62))
band.addLine(to: CGPoint(x: 300, y: -70))
band.addLine(to: CGPoint(x: 324, y: 58))
band.addLine(to: CGPoint(x: -296, y: 66))
band.closeSubpath()
ctx.setBlendMode(.multiply)
ctx.addPath(band); ctx.setFillColor(color(0xF5DE3C, 0.92)); ctx.fillPath()
ctx.restoreGState()

ctx.addPath(placed)
ctx.setFillColor(color(0x3846C4))
ctx.fillPath()
ctx.restoreGState()

// Hairline edge so the tile reads on light backgrounds.
ctx.addPath(shape); ctx.setStrokeColor(color(0x000000, 0.07)); ctx.setLineWidth(2); ctx.strokePath()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
