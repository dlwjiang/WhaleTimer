// Run from marketing/: swift scripts/social.swift
// Uses only the site's bundled artwork. No network or preview server.
import AppKit
let width = 1200, height = 630
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
func color(_ value: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(value >> 16 & 255) / 255, green: CGFloat(value >> 8 & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: 1)
}
color(0xf7f5ef).setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
func text(_ string: String, _ rect: NSRect, size: CGFloat, font: String, ink: Int) {
    (string as NSString).draw(in: rect, withAttributes: [.font: NSFont(name: font, size: size) ?? NSFont.systemFont(ofSize: size), .foregroundColor: color(ink)])
}
text("Tick & Kin", NSRect(x: 65, y: 515, width: 550, height: 60), size: 28, font: "HelveticaNeue-Bold", ink: 0x293e4a)
text("Make time.", NSRect(x: 62, y: 355, width: 570, height: 100), size: 76, font: "Georgia", ink: 0x293e4a)
text("Find your kin.", NSRect(x: 62, y: 265, width: 580, height: 100), size: 76, font: "Georgia-Italic", ink: 0xa3553b)
text("A cozy focus timer for iPhone & iPad.", NSRect(x: 66, y: 190, width: 530, height: 50), size: 23, font: "HelveticaNeue", ink: 0x596b71)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: NSRect(x: 665, y: 50, width: 485, height: 530), xRadius: 80, yRadius: 80).addClip()
color(0xfaecda).setFill(); NSRect(x: 665, y: 50, width: 485, height: 530).fill()
let room = NSImage(contentsOfFile: "public/art/window.webp")!
room.draw(in: NSRect(x: 665, y: 257, width: 485, height: 323))
let sprite = NSImage(contentsOfFile: "public/art/mochi.webp")!
sprite.draw(in: NSRect(x: 675, y: 285, width: 465, height: 310), from: NSRect(x: 0, y: 0, width: sprite.size.width / 2, height: sprite.size.height), operation: .sourceOver, fraction: 1)
color(0xffffff).setFill(); NSBezierPath(roundedRect: NSRect(x: 705, y: 90, width: 405, height: 145), xRadius: 18, yRadius: 18).fill()
color(0x315d75).setFill(); NSBezierPath(roundedRect: NSRect(x: 725, y: 110, width: 365, height: 105), xRadius: 10, yRadius: 10).fill()
text("25 : 00", NSRect(x: 766, y: 123, width: 310, height: 80), size: 65, font: "HelveticaNeue-Bold", ink: 0xffffff)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "public/social.png"))
