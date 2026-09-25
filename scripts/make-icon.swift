import AppKit

// Original vector artwork, rendered at every macOS icon size; no external assets.
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let tile = NSBezierPath(roundedRect: NSRect(x: 74, y: 74, width: 876, height: 876),
                            xRadius: 202, yRadius: 202)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(calibratedRed: 0.11, green: 0.37, blue: 0.30, alpha: 1).setFill()
    tile.fill()
    NSShadow().set()
    NSGradient(starting: NSColor(calibratedRed: 0.24, green: 0.61, blue: 0.46, alpha: 1),
               ending: NSColor(calibratedRed: 0.07, green: 0.32, blue: 0.29, alpha: 1))!
        .draw(in: tile, angle: -70)

    NSColor(calibratedRed: 0.99, green: 0.78, blue: 0.43, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 603, y: 650, width: 133, height: 133)).fill()

    let cream = NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.88, alpha: 1)
    cream.setStroke()
    let handle = NSBezierPath(ovalIn: NSRect(x: 616, y: 373, width: 144, height: 168))
    handle.lineWidth = 43
    handle.stroke()
    cream.setFill()
    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: 289, y: 582))
    cup.line(to: NSPoint(x: 663, y: 582))
    cup.line(to: NSPoint(x: 644, y: 384))
    cup.curve(to: NSPoint(x: 542, y: 294), controlPoint1: NSPoint(x: 639, y: 326), controlPoint2: NSPoint(x: 598, y: 294))
    cup.line(to: NSPoint(x: 409, y: 294))
    cup.curve(to: NSPoint(x: 307, y: 384), controlPoint1: NSPoint(x: 352, y: 294), controlPoint2: NSPoint(x: 313, y: 326))
    cup.close()
    cup.fill()
    NSBezierPath(roundedRect: NSRect(x: 260, y: 236, width: 446, height: 32), xRadius: 16, yRadius: 16).fill()

    for x: CGFloat in [384, 494] {
        let steam = NSBezierPath()
        steam.move(to: NSPoint(x: x, y: 640))
        steam.curve(to: NSPoint(x: x + 10, y: 772), controlPoint1: NSPoint(x: x - 42, y: 692),
                    controlPoint2: NSPoint(x: x + 49, y: 715))
        steam.lineWidth = 25
        steam.lineCapStyle = .round
        cream.withAlphaComponent(0.8).setStroke()
        steam.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size).write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size).png"))
    try drawIcon(size: size * 2).write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)@2x.png"))
}
