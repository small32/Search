// Generate macOS icon sizes from the same supplied artwork used inside the app.
import AppKit

let files = FileManager.default
let arguments = Array(CommandLine.arguments.dropFirst())
guard let destination = arguments.first else { fatalError("Usage: swift Icon/icon.swift ICONSET [ASSET_CATALOG]") }
let out = URL(fileURLWithPath: destination)
let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Sources/SearcheXtra/Resources/AppIcon.png")
guard let image = NSImage(contentsOf: source) else { fatalError("Missing app icon: \(source.path)") }
try files.createDirectory(at: out, withIntermediateDirectories: true)
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { fatalError("Cannot allocate icon bitmap") }
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        context.cgContext.clear(bounds)
        let radius = CGFloat(pixels) / 4
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).addClip()
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:])
        else { fatalError("Cannot encode icon bitmap") }
        try png.write(to: out.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
if arguments.count > 1 {
    let catalog = URL(fileURLWithPath: arguments[1])
    let appIcon = catalog.appendingPathComponent("AppIcon.appiconset")
    try files.createDirectory(at: appIcon, withIntermediateDirectories: true)
    for entry in entries {
        let name = entry["filename"]!
        try files.copyItem(at: out.appendingPathComponent(name), to: appIcon.appendingPathComponent(name))
    }
    try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]])
        .write(to: catalog.appendingPathComponent("Contents.json"))
    let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: appIcon.appendingPathComponent("Contents.json"))
}
