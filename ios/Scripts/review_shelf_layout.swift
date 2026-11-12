import AppKit

/// Offline review of the actual core geometry and bundled artwork. No server/app launch.
@main struct ShelfReview {
    struct Source: Decodable {
        struct Reference: Decodable {
            let scenario: String
            let companion: String
            let viewport: [Double]
            let stage: [Double]
            let shelfY: Double
            let minimumY: Double
            let referenceFrame: [Double]
            let kind: String
            let confirmed: Bool
        }
        let references: [Reference]
    }
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("ios/Verification/ShelfCalibration")
        let refs = try JSONDecoder().decode(Source.self, from: Data(contentsOf: output.appendingPathComponent("references.json"))).references
        var cache: [String: CGImage] = [:]
        func asset(_ name: String, file: String) -> CGImage {
            if let image = cache[name] { return image }
            let image = NSImage(contentsOf: root.appendingPathComponent("ios/Banke/Assets.xcassets/\(name).imageset/\(file)"))!
            var rect = CGRect(origin: .zero, size: image.size)
            let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
            cache[name] = cg
            return cg
        }
        var report: [[String: Any]] = []
        for scenario in Array(Set(refs.map(\.scenario))).sorted() {
            let group = refs.filter { $0.scenario == scenario }
            let size = CGSize(width: group[0].viewport[0], height: group[0].viewport[1])
            let scale = 240 / size.width
            let tileHeight = Int(ceil(size.height * scale)) + 32
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: tileHeight * 3,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            let context = NSGraphicsContext.current!.cgContext
            context.translateBy(x: 0, y: CGFloat(tileHeight * 3)); context.scaleBy(x: 1, y: -1)
            for (index, ref) in group.enumerated() {
                let companion = Companion(rawValue: ref.companion)!
                let room = companion.duoRoom
                let stage = CGSize(width: ref.stage[0], height: ref.stage[1])
                let frame = ShelfComposition(viewport: size, stage: stage, shelfY: ref.shelfY,
                    minimumY: ref.minimumY, maximumY: stage.height + 32).frame(companion: companion)
                let target = CGRect(x: ref.referenceFrame[0], y: ref.referenceFrame[1],
                                    width: ref.referenceFrame[2], height: ref.referenceFrame[3])
                let delta = frame.height / target.height - 1
                report.append(["scenario": scenario, "companion": companion.rawValue, "confirmed": ref.confirmed,
                    "sizeErrorPercent": Double(delta * 100),
                    "seatErrorPoints": Double(frame.minY + ShelfCharacterMetrics(companion).seatY * frame.height - ref.shelfY)])
                let top: CGFloat = scenario == "duoHinge" ? 0 : scenario == "duoP" ? 174
                    : scenario == "duoL" ? 84 : scenario.hasSuffix("P") && (scenario.hasPrefix("phone") || scenario.hasPrefix("max")) ? 140
                    : scenario.hasSuffix("L") && (scenario.hasPrefix("phone") || scenario.hasPrefix("max")) ? 90 : 108
                let left: CGFloat = size.width < size.height ? (size.width - stage.width) / 2
                    : (scenario == "phoneL" || scenario == "maxL") ? 59 : 0
                let origin = CGPoint(x: left, y: top)
                context.saveGState()
                context.translateBy(x: CGFloat(index % 4) * 240, y: CGFloat(index / 4 * tileHeight))
                context.setFillColor(NSColor.white.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 240, height: tileHeight))
                context.saveGState(); context.scaleBy(x: 1, y: -1)
                let label = "\(companion.rawValue)   \(String(format: "%+.1f%%", delta * 100))\(ref.confirmed ? "" : " vs old")"
                (label as NSString).draw(at: CGPoint(x: 8, y: -24), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.darkGray])
                context.restoreGState()
                context.translateBy(x: 0, y: 32); context.scaleBy(x: scale, y: scale)
                context.clip(to: CGRect(origin: .zero, size: size))
                context.setFillColor(NSColor(srgbRed: 0.94, green: 0.96, blue: 0.98, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                func draw(_ image: CGImage, in rect: CGRect) {
                    context.saveGState(); context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
                    context.draw(image, in: CGRect(origin: .zero, size: rect.size)); context.restoreGState()
                }
                let painting = ref.kind == "hinge" ? room.hingeFrame(width: size.width, hingeY: size.height * 0.5)
                    : DeviceRoomFormat.resolve(size: size, isPad: false).imageFrame(size: size,
                        ledgeY: origin.y + ref.shelfY, room: room, characterX: origin.x + stage.width / 2)
                draw(asset(room.asset, file: "room.png"), in: painting)
                let sheet = asset(companion.duoSprite, file: "poses.png")
                let sprite = sheet.cropping(to: CGRect(x: 0, y: 0, width: sheet.width / 2, height: sheet.height))!
                draw(sprite, in: frame.offsetBy(dx: origin.x, dy: origin.y))
                let bounds = DeviceRoomSprite.bounds(companion: companion, poked: false)
                let previousVisible = CGRect(x: origin.x + target.minX + bounds.minX * target.width,
                    y: origin.y + target.minY + bounds.minY * target.height,
                    width: bounds.width * target.width, height: bounds.height * target.height)
                context.setStrokeColor(NSColor.systemOrange.cgColor); context.setLineWidth(1.3 / scale)
                context.setLineDash(phase: 0, lengths: [5 / scale, 3 / scale]); context.stroke(previousVisible)
                context.setLineDash(phase: 0, lengths: []); context.setStrokeColor(NSColor.systemTeal.cgColor)
                context.move(to: CGPoint(x: origin.x, y: origin.y + ref.shelfY))
                context.addLine(to: CGPoint(x: origin.x + stage.width, y: origin.y + ref.shelfY)); context.strokePath()
                context.restoreGState()
            }
            NSGraphicsContext.restoreGraphicsState()
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(scenario).png"))
        }
        let confirmed = report.filter { $0["confirmed"] as! Bool }
        let errors = confirmed.map { abs($0["sizeErrorPercent"] as! Double) }
        let summary: [String: Any] = ["comparisonCount": report.count, "confirmedReferenceCount": confirmed.count,
            "unverifiedBaselineCount": report.count - confirmed.count,
            "meanAbsoluteSizeErrorPercent": errors.reduce(0,+)/Double(errors.count),
            "maximumAbsoluteSizeErrorPercent": errors.max()!, "comparisons": report]
        try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("comparison.json"))
        let scenarios = [("phoneP", "iPhone portrait — unverified"), ("phoneL", "iPhone landscape — unverified"),
            ("maxP", "iPhone Max portrait — unverified"), ("maxL", "iPhone Max landscape — unverified"),
            ("miniP", "iPad mini portrait"), ("miniL", "iPad mini landscape"),
            ("proP", "iPad Pro 11 portrait"), ("proL", "iPad Pro 11 landscape"),
            ("duoP", "Duo front portrait"), ("duoL", "Duo front landscape"),
            ("duoOpen", "Duo open landscape"), ("duoHinge", "Duo hinge")]
        let options = scenarios.map { key, title in
            "<option value='\(key).png'\(key == "maxP" ? " selected" : "")>\(title)</option>"
        }.joined()
        let mean = String(format: "%.2f", errors.reduce(0,+)/Double(errors.count))
        let maximum = String(format: "%.2f", errors.max()!)
        let html = """
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Tick & Kin — Shelf comparison</title><style>body{margin:0;background:#f6f5f1;color:#243c43;font:16px/1.5 system-ui}main{max-width:1100px;margin:auto;padding:28px}h1{font-size:28px}select{font:inherit;padding:10px;max-width:100%;margin:12px 0 20px}img{max-width:100%;height:auto}a{color:#286c68}.note{background:#fff0d7;padding:16px;border-radius:8px}</style>
        <main><h1>Shelf composition review</h1><p><strong>\(confirmed.count) confirmed Duo/iPad references</strong> · \(mean)% average size difference · \(maximum)% maximum.</p>
        <p class="note">The 48 phone/Max cases have no confirmed numeric export. Their dashed boxes show the old baseline, not an approved target; they are excluded from the tolerance claim. The earlier report incorrectly counted them as confirmed.</p>
        <p>Teal lines mark the sitting surface. Orange boxes show comparison bounds. These are offline compositions without the app UI, using representative header allowances.</p>
        <select aria-label="Composition" onchange="document.getElementById('sheet').src=this.value;document.getElementById('sheet').alt=this.options[this.selectedIndex].text">\(options)</select>
        <img id="sheet" src="maxP.png" alt="iPhone Max portrait — unverified extrapolation">
        <p><a href="NativeMax/portrait.png">Actual Pro Max portrait</a> · <a href="NativeMax/landscape.png">Actual Pro Max landscape</a></p>
        <p><a href="README.md">Method and limitations</a> · <a href="comparison.json">Measured results</a></p></main></html>
        """
        try html.write(to: output.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        print("Rendered \(report.count) comparisons in \(output.path)")
    }
}
