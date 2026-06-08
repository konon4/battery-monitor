// Generates a 1024×1024 app icon PNG: a battery with a health "pulse" line on a green
// gradient squircle. Run: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024.0
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// ── Squircle background with vertical green gradient ──
let inset = 84.0
let bgRect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 196, yRadius: 196)
ctx.saveGState()
bgPath.addClip()
let grad = NSGradient(colors: [color(74, 222, 128), color(16, 163, 107)],
                      atLocations: [0, 1], colorSpace: .sRGB)!
grad.draw(in: bgRect, angle: -90)
// subtle top highlight
color(255, 255, 255, 0.16).setFill()
NSBezierPath(roundedRect: NSRect(x: inset, y: size*0.52, width: size - 2*inset, height: (size-2*inset)*0.48),
             xRadius: 196, yRadius: 196).fill()
ctx.restoreGState()

// ── Battery body (white rounded outline) ──
let bodyW = 540.0, bodyH = 312.0
let bodyX = (size - bodyW)/2 - 24
let bodyY = (size - bodyH)/2
let stroke = 30.0
let body = NSBezierPath(roundedRect: NSRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH),
                        xRadius: 66, yRadius: 66)
body.lineWidth = stroke
color(255, 255, 255).setStroke()
body.stroke()

// terminal nub
let nub = NSBezierPath(roundedRect: NSRect(x: bodyX + bodyW + 14, y: size/2 - 52, width: 40, height: 104),
                       xRadius: 20, yRadius: 20)
color(255, 255, 255).setFill()
nub.fill()

// ── Health "pulse" (ECG) line across the battery ──
let pulse = NSBezierPath()
let pad = 56.0
let left = bodyX + pad, right = bodyX + bodyW - pad
let midY = size/2
let pts: [(Double, Double)] = [
    (left,            midY),
    (left + 96,       midY),
    (left + 150,      midY + 86),
    (left + 214,      midY - 120),
    (left + 286,      midY + 40),
    (left + 330,      midY),
    (right,           midY),
]
pulse.move(to: NSPoint(x: pts[0].0, y: pts[0].1))
for p in pts.dropFirst() { pulse.line(to: NSPoint(x: p.0, y: p.1)) }
pulse.lineWidth = 26
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
color(255, 255, 255).setStroke()
pulse.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
