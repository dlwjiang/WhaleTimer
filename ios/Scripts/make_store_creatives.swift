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
// Brand headers: original layout, real app capture, no fake device or invented controls.
let screen = release.appendingPathComponent("screenshots/duo-tabletop/01-mochi-focus.png")
for (name,w,h) in [("app-store-header",3840,1646),("app-store-search",3840,2560)] {
    try canvas(w,h,release.appendingPathComponent("marketing/\(name).png")) { width,height in
        let square = w == h
        let margin = width*0.055
        let copyWidth = square ? width-margin*2 : width*0.52
        let top = height-margin
        text("TICK & KIN", NSRect(x:margin,y:top-height*0.055,width:copyWidth,height:height*0.05),height*0.032)
        text(square ? "Make room\nfor focus." : "Make room\nfor focus.", NSRect(x:margin,y:top-height*(square ? 0.30 : 0.42),width:copyWidth,height:height*(square ? 0.25 : 0.36)), height*(square ? 0.080 : 0.112),"Georgia")
        text("A cozy timer. A little company.", NSRect(x:margin,y:top-height*(square ? 0.37 : 0.52),width:copyWidth,height:height*0.06),height*(square ? 0.025 : 0.034),"Manrope-Bold",0x52676b)
        if !square {
            text("Focus, with a little company.\nFind your rhythm.", NSRect(x:margin,y:height*0.15,width:copyWidth,height:height*0.11),height*0.028,"Manrope-Bold",0x52676b)
            let sh=height*0.88,sw=sh*2007/2853
            picture(screen,in:NSRect(x:width-sw-margin,y:height*0.06,width:sw,height:sh),radius:width*0.025)
        } else {
            let sh=height*0.52,sw=sh*2007/2853
            picture(screen,in:NSRect(x:(width-sw)/2,y:height*0.025,width:sw,height:sh),radius:width*0.025)
        }
    }
}
print("Composed App Store header and search artwork from native UI.")
