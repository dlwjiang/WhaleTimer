// Run from repository root: swift ios/Scripts/make_release_artwork.swift
// Composes native screenshot layouts; never redraws or generates the app UI.
import AppKit
import CoreText
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let release = root.appendingPathComponent("ios/Release/1.0")
CTFontManagerRegisterFontsForURL(root.appendingPathComponent("ios/Banke/Fonts/Manrope-Bold.ttf") as CFURL, .process, nil)
func ink(_ n: Int) -> NSColor { NSColor(srgbRed: CGFloat(n >> 16 & 255)/255, green: CGFloat(n >> 8 & 255)/255, blue: CGFloat(n & 255)/255, alpha: 1) }
func text(_ s: String, _ rect: NSRect, _ size: CGFloat, _ font: String = "Manrope-Bold", _ color: Int = 0x293e4a) {
    (s as NSString).draw(in: rect, withAttributes: [.font: NSFont(name: font, size: size) ?? NSFont.systemFont(ofSize: size), .foregroundColor: ink(color)])
}
func canvas(_ width: Int, _ height: Int, _ path: URL, _ draw: (CGFloat, CGFloat) -> Void) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    ink(0xf7f3eb).setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    draw(CGFloat(width), CGFloat(height))
    NSGraphicsContext.restoreGraphicsState()
    try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    let b = NSBitmapImageRep(cgImage: context.makeImage()!)
    try b.representation(using: .png, properties: [:])!.write(to: path)
}
func picture(_ url: URL, in rect: NSRect, radius: CGFloat = 0) {
    let image = NSImage(contentsOf: url)!
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}
let stories = [
    ("01-mochi-focus", "Make room for focus.", "A cozy Pomodoro timer. Three companions included."),
    ("02-pip-focus", "Find your kind of company.", "Mochi, Pip and Pebble are yours, free."),
    ("04-your-rhythm", "Your time. Your rhythm.", "Adjust your sessions. Turn breaks on or off."),
    ("06-luna-focus", "A little magic for your desk.", "Luna · Moonlight Academy · Optional paid pack")
]
let dirs = try FileManager.default.contentsOfDirectory(at: release.appendingPathComponent("screenshots"), includingPropertiesForKeys: nil)
for dir in dirs {
    for (file, heading, subtitle) in stories {
        let source = dir.appendingPathComponent(file + ".png")
        guard let image = NSImage(contentsOf: source), let rep = image.representations.first else { continue }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        try canvas(w, h, release.appendingPathComponent("store-upload/en/\(dir.lastPathComponent)/\(file).png")) { width,height in
            let margin = width * 0.055
            let header = height * (width > height ? 0.18 : 0.16)
            text("TICK & KIN", NSRect(x: margin, y: height-header*0.24, width: width-margin*2, height: header*0.16), header*0.085)
            text(heading, NSRect(x: margin, y: height-header*0.66, width: width-margin*2, height: header*0.40), min(width*0.052,header*0.29), "Georgia")
            text(subtitle, NSRect(x: margin, y: height-header*0.89, width: width-margin*2, height: header*0.20), min(width*0.023,header*0.125), "Manrope-Bold", 0x52676b)
            let fit = min((width-margin*2)/CGFloat(w), (height-header-margin*0.7)/CGFloat(h))
            let rect = NSRect(x: (width-CGFloat(w)*fit)/2, y: margin*0.35, width: CGFloat(w)*fit, height: CGFloat(h)*fit)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.17); shadow.shadowBlurRadius = width*0.015; shadow.shadowOffset = NSSize(width: 0, height: -width*0.008); shadow.set()
            ink(0xffffff).setFill(); NSBezierPath(roundedRect: rect, xRadius: width*0.025, yRadius: width*0.025).fill()
            NSGraphicsContext.restoreGraphicsState()
            picture(source, in: rect, radius: width*0.025)
        }
    }
}
// Brand headers: original layout, real app capture, no fake device or invented controls.
let screen = release.appendingPathComponent("screenshots/duo-tabletop/01-mochi-focus.png")
for (name,w,h) in [("launch-header",2400,1200),("social-preview",1200,630),("launch-square",1080,1080)] {
    try canvas(w,h,release.appendingPathComponent("marketing/\(name).png")) { width,height in
        let square = w == h
        let margin = width*0.055
        let copyWidth = square ? width-margin*2 : width*0.52
        let top = height-margin
        text("TICK & KIN", NSRect(x:margin,y:top-height*0.055,width:copyWidth,height:height*0.05),height*0.032)
        text(square ? "Make room\nfor focus." : "Make room\nfor focus.", NSRect(x:margin,y:top-height*(square ? 0.30 : 0.42),width:copyWidth,height:height*(square ? 0.25 : 0.36)), height*(square ? 0.080 : 0.112),"Georgia")
        text("A cozy timer. A little company.", NSRect(x:margin,y:top-height*(square ? 0.37 : 0.52),width:copyWidth,height:height*0.06),height*(square ? 0.025 : 0.034),"Manrope-Bold",0x52676b)
        if !square {
            text("Free timer + three companions\nOptional packs. No subscription.", NSRect(x:margin,y:height*0.15,width:copyWidth,height:height*0.11),height*0.028,"Manrope-Bold",0x52676b)
            let sh=height*0.88,sw=sh*2007/2853
            picture(screen,in:NSRect(x:width-sw-margin,y:height*0.06,width:sw,height:sh),radius:width*0.025)
        } else {
            let sh=height*0.52,sw=sh*2007/2853
            picture(screen,in:NSRect(x:(width-sw)/2,y:height*0.025,width:sw,height:sh),radius:width*0.025)
        }
    }
}
print("Composed store screenshot cards and three brand headers from unmodified native UI.")
