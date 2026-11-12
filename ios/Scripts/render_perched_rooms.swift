import AppKit

@main struct Review {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("ios/Verification/PerchedRooms")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let formats: [(String, CGSize, CGFloat)] = [("phone", CGSize(width: 393, height: 852), 120),
            ("phone-landscape", CGSize(width: 852, height: 393), 90),
            ("ipad-portrait", CGSize(width: 1024, height: 1366), 110),
            ("ipad-landscape", CGSize(width: 1366, height: 1024), 110)]
        for (name, size, top) in formats {
            let scale = 320 / size.width
            let tileH = Int(size.height * scale)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320 * 6, pixelsHigh: tileH,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.translateBy(x: 0, y: CGFloat(tileH)); ctx.scaleBy(x: scale, y: -scale)
            for (i, companion) in [Companion.mochi, .pip, .pebble, .jun, .luna, .nova].enumerated() {
                ctx.saveGState(); ctx.translateBy(x: CGFloat(i) * size.width, y: 0)
                ctx.clip(to: CGRect(origin: .zero, size: size))
                let format = DeviceRoomFormat.resolve(size: size, isPad: name.hasPrefix("ipad"))
                let ledge = max(top + 72, size.height * (format.isLandscape ? 0.65 : 0.46))
                let center = size.width * (format.isLandscape ? 0.23 : 0.5)
                let room = companion.duoRoom
                let frame = format.imageFrame(size: size, ledgeY: ledge, room: room, characterX: center)
                let source = NSImage(contentsOf: root.appendingPathComponent("ios/Banke/Assets.xcassets/\(room.asset).imageset/room.png"))!
                var rect = CGRect(origin: .zero, size: source.size)
                let cg = source.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
                func draw(_ image: CGImage, _ rect: CGRect) {
                    ctx.saveGState(); ctx.translateBy(x: rect.minX, y: rect.maxY); ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size)); ctx.restoreGState()
                }
                let colors: [DuoRoom: Int] = [.window: 0xfaecda, .study: 0xffe3b9,
                    .river: 0xfce8d2, .cafe: 0xffe0bc, .academy: 0xf6e0dc, .orbit: 0xfce5c6]
                let color = colors[room]!
                ctx.setFillColor(NSColor(srgbRed: CGFloat((color >> 16) & 255) / 255,
                    green: CGFloat((color >> 8) & 255) / 255, blue: CGFloat(color & 255) / 255, alpha: 1).cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
                let paper = NSImage(contentsOf: root.appendingPathComponent("ios/Banke/Assets.xcassets/paper-texture.imageset/image.png"))!
                var paperRect = CGRect(origin: .zero, size: paper.size)
                let paperCG = paper.cgImage(forProposedRect: &paperRect, context: nil, hints: nil)!
                let paperScale = max(size.width / paper.size.width, size.height / paper.size.height)
                let paperSize = CGSize(width: paper.size.width * paperScale, height: paper.size.height * paperScale)
                ctx.saveGState(); ctx.setBlendMode(.luminosity); ctx.setAlpha(0.18)
                draw(paperCG, CGRect(x: (size.width - paperSize.width) / 2,
                    y: (size.height - paperSize.height) / 2, width: paperSize.width, height: paperSize.height))
                ctx.restoreGState()
                // Same source/frame as runtime; show the lower transition with 40 alpha bands.
                let solidHeight = CGFloat(cg.height) * 0.9
                draw(cg.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: solidHeight))!,
                     CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height * 0.9))
                for band in 0..<40 {
                    let y = 0.9 + CGFloat(band) / 400
                    ctx.setAlpha(1 - CGFloat(band) / 40)
                    let slice = cg.cropping(to: CGRect(x: 0, y: CGFloat(cg.height) * y, width: CGFloat(cg.width), height: CGFloat(cg.height) / 400 + 1))!
                    draw(slice, CGRect(x: frame.minX, y: frame.minY + frame.height * y, width: frame.width, height: frame.height / 400 + 1))
                }
                ctx.setAlpha(1)
                let feet = max(top + 100, size.height * (format.isLandscape ? 0.77 : 0.54)) + min(20, size.height * 0.025)
                let width = format.isLandscape ? size.width * 0.46 : min(760, size.width)
                let height = format.isLandscape ? size.height - 24 - top : feet - top + 12
                var spriteFrame = DeviceRoomSprite.perchedFrame(companion: companion, width: width, height: height, ledgeY: ledge - top)
                spriteFrame.origin.x += center - width / 2; spriteFrame.origin.y += top
                let sprite = NSImage(contentsOf: root.appendingPathComponent("ios/Banke/Assets.xcassets/\(companion.duoSprite).imageset/poses.png"))!
                var spriteRect = CGRect(origin: .zero, size: sprite.size)
                let sheet = sprite.cgImage(forProposedRect: &spriteRect, context: nil, hints: nil)!
                draw(sheet.cropping(to: CGRect(x: 0, y: 0, width: sheet.width / 2, height: sheet.height))!, spriteFrame)
                ctx.restoreGState()
            }
            NSGraphicsContext.restoreGraphicsState()
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name).png"))
        }
    }
}
