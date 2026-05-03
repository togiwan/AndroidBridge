import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let pngURL = resourcesURL.appendingPathComponent("AppIcon-1024.png")
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.22
    let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: corner, yRadius: corner)
    backgroundPath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.26, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.46, alpha: 1)
    ])!
    gradient.draw(in: bounds, angle: 42)

    NSColor(calibratedWhite: 1, alpha: 0.14).setFill()
    NSBezierPath(ovalIn: CGRect(x: size * 0.58, y: size * 0.58, width: size * 0.52, height: size * 0.52)).fill()
    NSColor(calibratedWhite: 0, alpha: 0.12).setFill()
    NSBezierPath(ovalIn: CGRect(x: -size * 0.12, y: -size * 0.08, width: size * 0.52, height: size * 0.52)).fill()

    let cablePath = NSBezierPath()
    cablePath.move(to: CGPoint(x: size * 0.22, y: size * 0.47))
    cablePath.curve(
        to: CGPoint(x: size * 0.78, y: size * 0.47),
        controlPoint1: CGPoint(x: size * 0.39, y: size * 0.34),
        controlPoint2: CGPoint(x: size * 0.61, y: size * 0.60)
    )
    cablePath.lineWidth = size * 0.055
    cablePath.lineCapStyle = .round
    NSColor(calibratedWhite: 1, alpha: 0.88).setStroke()
    cablePath.stroke()

    let plugRect = CGRect(x: size * 0.72, y: size * 0.415, width: size * 0.13, height: size * 0.11)
    NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: plugRect, xRadius: size * 0.025, yRadius: size * 0.025).fill()

    NSColor(calibratedWhite: 1, alpha: 0.72).setStroke()
    let prongPath = NSBezierPath()
    prongPath.lineWidth = size * 0.022
    prongPath.lineCapStyle = .round
    prongPath.move(to: CGPoint(x: size * 0.86, y: size * 0.49))
    prongPath.line(to: CGPoint(x: size * 0.91, y: size * 0.49))
    prongPath.move(to: CGPoint(x: size * 0.86, y: size * 0.45))
    prongPath.line(to: CGPoint(x: size * 0.91, y: size * 0.45))
    prongPath.stroke()

    let phoneRect = CGRect(x: size * 0.22, y: size * 0.22, width: size * 0.34, height: size * 0.56)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.25)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = CGSize(width: 0, height: -size * 0.016)
    shadow.set()

    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: phoneRect, xRadius: size * 0.06, yRadius: size * 0.06).fill()
    NSGraphicsContext.restoreGraphicsState()

    let screenRect = phoneRect.insetBy(dx: size * 0.035, dy: size * 0.058)
    NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.15, alpha: 1).setFill()
    NSBezierPath(roundedRect: screenRect, xRadius: size * 0.035, yRadius: size * 0.035).fill()

    NSColor(calibratedRed: 0.22, green: 0.80, blue: 0.38, alpha: 1).setFill()
    let headRect = CGRect(x: size * 0.335, y: size * 0.49, width: size * 0.11, height: size * 0.075)
    NSBezierPath(roundedRect: headRect, xRadius: size * 0.025, yRadius: size * 0.025).fill()
    NSBezierPath(rect: CGRect(x: size * 0.318, y: size * 0.435, width: size * 0.145, height: size * 0.075)).fill()

    NSColor(calibratedRed: 0.04, green: 0.13, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: size * 0.362, y: size * 0.524, width: size * 0.014, height: size * 0.014)).fill()
    NSBezierPath(ovalIn: CGRect(x: size * 0.404, y: size * 0.524, width: size * 0.014, height: size * 0.014)).fill()

    NSColor(calibratedWhite: 1, alpha: 0.88).setStroke()
    let arrowPath = NSBezierPath()
    arrowPath.lineWidth = size * 0.024
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    arrowPath.move(to: CGPoint(x: size * 0.63, y: size * 0.64))
    arrowPath.line(to: CGPoint(x: size * 0.76, y: size * 0.64))
    arrowPath.line(to: CGPoint(x: size * 0.72, y: size * 0.68))
    arrowPath.move(to: CGPoint(x: size * 0.76, y: size * 0.64))
    arrowPath.line(to: CGPoint(x: size * 0.72, y: size * 0.60))
    arrowPath.move(to: CGPoint(x: size * 0.76, y: size * 0.36))
    arrowPath.line(to: CGPoint(x: size * 0.63, y: size * 0.36))
    arrowPath.line(to: CGPoint(x: size * 0.67, y: size * 0.40))
    arrowPath.move(to: CGPoint(x: size * 0.63, y: size * 0.36))
    arrowPath.line(to: CGPoint(x: size * 0.67, y: size * 0.32))
    arrowPath.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixelSize: Int) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap"])
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render PNG"])
    }

    try data.write(to: url)
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try writePNG(drawIcon(size: 512), to: pngURL, pixelSize: 1024)

for (name, size) in sizes {
    let image = drawIcon(size: CGFloat(size) / 2)
    try writePNG(image, to: iconsetURL.appendingPathComponent(name), pixelSize: size)
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

func appendChunk(type: String, pngURL: URL, to data: inout Data) throws {
    let pngData = try Data(contentsOf: pngURL)
    data.append(type.data(using: .ascii)!)
    appendBigEndianUInt32(UInt32(pngData.count + 8), to: &data)
    data.append(pngData)
}

let icnsChunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var chunkData = Data()
for (type, name) in icnsChunks {
    try appendChunk(type: type, pngURL: iconsetURL.appendingPathComponent(name), to: &chunkData)
}

var icnsData = Data("icns".utf8)
appendBigEndianUInt32(UInt32(chunkData.count + 8), to: &icnsData)
icnsData.append(chunkData)
try icnsData.write(to: icnsURL)

print("Generated AppIcon PNGs in \(iconsetURL.path)")
print("Generated \(icnsURL.path)")
