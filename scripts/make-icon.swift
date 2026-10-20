import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/make-icon.swift <output.iconset>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

// A vector thermometer is rendered at every native icon size to keep small icons sharp.
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
                                             pixelsHigh: pixels, bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true,
                                             isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Cannot create icon bitmap")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

        let tile = NSBezierPath(roundedRect: NSRect(x: 82, y: 82, width: 860, height: 860),
                                xRadius: 194, yRadius: 194)
        let gradient = NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.54, blue: 0.96, alpha: 1),
                                  ending: NSColor(srgbRed: 0.08, green: 0.27, blue: 0.71, alpha: 1))!
        gradient.draw(in: tile, angle: -90)

        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 424, y: 330, width: 136, height: 450),
                     xRadius: 68, yRadius: 68).fill()
        NSBezierPath(ovalIn: NSRect(x: 366, y: 218, width: 252, height: 252)).fill()

        NSColor(srgbRed: 1, green: 0.42, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 471, y: 340, width: 42, height: 290),
                     xRadius: 21, yRadius: 21).fill()
        NSBezierPath(ovalIn: NSRect(x: 410, y: 262, width: 164, height: 164)).fill()

        NSColor.white.withAlphaComponent(0.8).setFill()
        for y in [520, 610, 700] {
            NSBezierPath(roundedRect: NSRect(x: 598, y: y, width: 66, height: 18),
                         xRadius: 9, yRadius: 9).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Cannot encode icon")
        }
        let suffix = scale == 2 ? "@2x" : ""
        let file = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try png.write(to: file)
        let verified = NSBitmapImageRep(data: try Data(contentsOf: file))!
        precondition(verified.pixelsWide == pixels && verified.pixelsHigh == pixels,
                     "Icon dimensions must match the macOS representation")
    }
}
print("10 icon representations generated and verified")
