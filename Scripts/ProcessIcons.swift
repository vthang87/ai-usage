import AppKit
import Foundation

let assets = "/Users/thangdang/.cursor/projects/Users-thangdang-Sites-AI-Usage/assets"
let repo = "/Users/thangdang/Sites/AI Usage"

func load(_ name: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: "\(assets)/\(name)") else {
        fatalError("missing \(name)")
    }
    return image
}

func makeRep(width: Int, height: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
}

func rasterize(_ image: NSImage, width: Int, height: Int) -> NSBitmapImageRep {
    let rep = makeRep(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: width, height: height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func mutate(_ rep: NSBitmapImageRep, _ body: (_ r: inout UInt8, _ g: inout UInt8, _ b: inout UInt8, _ a: inout UInt8) -> Void) {
    guard let data = rep.bitmapData else { return }
    let row = rep.bytesPerRow
    let spp = max(rep.samplesPerPixel, 4)
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            let i = y * row + x * spp
            var r = data[i], g = data[i + 1], b = data[i + 2], a = spp > 3 ? data[i + 3] : 255
            body(&r, &g, &b, &a)
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
            if spp > 3 { data[i + 3] = a }
        }
    }
}

func cropToOpaque(_ rep: NSBitmapImageRep, padding: Int) -> NSBitmapImageRep {
    var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
    guard let data = rep.bitmapData else { return rep }
    let row = rep.bytesPerRow
    let spp = max(rep.samplesPerPixel, 4)
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            if data[y * row + x * spp + 3] > 24 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }
    minX = max(0, minX - padding)
    minY = max(0, minY - padding)
    maxX = min(rep.pixelsWide - 1, maxX + padding)
    maxY = min(rep.pixelsHigh - 1, maxY + padding)
    let w = max(1, maxX - minX + 1)
    let h = max(1, maxY - minY + 1)
    let side = max(w, h)
    let cropped = makeRep(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: cropped)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    let ox = (side - w) / 2
    let oy = (side - h) / 2
    let source = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
    source.addRepresentation(rep)
    source.draw(
        in: NSRect(x: ox, y: oy, width: w, height: h),
        from: NSRect(x: minX, y: minY, width: w, height: h),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return cropped
}

let iconSet = "\(repo)/AIUsage/Assets.xcassets/AppIcon.appiconset"
let appIcon = load("app-icon-1024.png")
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
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in sizes {
    writePNG(rasterize(appIcon, width: px, height: px), to: "\(iconSet)/\(name)")
}

let menu = rasterize(load("menubar-robot.png"), width: 256, height: 256)
mutate(menu) { r, g, b, a in
    let luma = max(r, max(g, b))
    r = 0; g = 0; b = 0
    a = luma
}
let menuCropped = cropToOpaque(menu, padding: 10)
let menuDir = "\(repo)/Brand.xcassets/MenuBarRobot.imageset"
writePNG(rasterize(NSImage(cgImage: menuCropped.cgImage!, size: .zero), width: 32, height: 32), to: "\(menuDir)/MenuBarRobot.png")
writePNG(rasterize(NSImage(cgImage: menuCropped.cgImage!, size: .zero), width: 64, height: 64), to: "\(menuDir)/MenuBarRobot@2x.png")

func processCube(source: String, destName: String) {
    let rep = rasterize(load(source), width: 512, height: 512)
    mutate(rep) { r, g, b, a in
        let luma = Int(max(r, max(g, b)))
        a = luma > 18 ? 255 : UInt8(min(255, luma * 8))
    }
    let cropped = cropToOpaque(rep, padding: 28)
    writePNG(cropped, to: "\(repo)/Brand.xcassets/\(destName).imageset/\(destName).png")
}

processCube(source: "cube-codex.png", destName: "CodexCube")
processCube(source: "cube-cursor.png", destName: "CursorCube")
print("ok")
