// Renders AppIcon.icns: three bars on a coral plate, the same three limits the app tracks.
// Run from build.sh — takes the output directory as its only argument.
import AppKit

let coralLight = NSColor(srgbRed: 0.93, green: 0.53, blue: 0.42, alpha: 1)
let coralDark = NSColor(srgbRed: 0.77, green: 0.36, blue: 0.24, alpha: 1)
let values: [CGFloat] = [0.22, 0.73, 0.58]

func draw(side: CGFloat) {
    let inset = side * 0.09
    let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let corner = plate.width * 0.2237

    NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner).addClip()
    NSGradient(starting: coralLight, ending: coralDark)!.draw(in: plate, angle: -90)

    let barWidth = plate.width * 0.15
    let gap = plate.width * 0.09
    let bottom = plate.minY + plate.height * 0.2
    let maxHeight = plate.height * 0.6
    var x = plate.midX - (barWidth * 3 + gap * 2) / 2

    for value in values {
        let radius = barWidth / 2

        NSColor(white: 1, alpha: 0.28).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: x, y: bottom, width: barWidth, height: maxHeight),
            xRadius: radius, yRadius: radius
        ).fill()

        NSColor.white.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: x, y: bottom, width: barWidth, height: maxHeight * value),
            xRadius: radius, yRadius: radius
        ).fill()

        x += barWidth + gap
    }
}

func png(side: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    draw(side: CGFloat(side))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(side: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(side: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("wrote \(iconset.path)")
