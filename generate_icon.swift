import CoreGraphics
import Foundation
import ImageIO

// Configuration
let width = 1024
let height = 1024
let outputPath = FileManager.default.currentDirectoryPath + "/icon_512x512.png"

// Create Context
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
else {
    print("Failed to create graphics context")
    exit(1)
}

// --- Drawing ---

// 1. Clip to Rounded Rect (Squircle-ish)
let rect = CGRect(x: 0, y: 0, width: width, height: height)
let radius = CGFloat(width) * 0.2237
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

context.addPath(path)
context.clip()

// 2. Draw Gradient Background
// Windows 11 Blue: Light (Top-Left) to Dark (Bottom-Right)
let colors =
    [
        CGColor(srgbRed: 0 / 255, green: 164 / 255, blue: 239 / 255, alpha: 1.0),  // Light Blue
        CGColor(srgbRed: 0 / 255, green: 90 / 255, blue: 180 / 255, alpha: 1.0),  // Dark Blue
    ] as CFArray

guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])
else {
    print("Failed to create gradient")
    exit(1)
}

// Draw from Top-Left to Bottom-Right (CoreGraphics origin is Bottom-Left)
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(height)),
    end: CGPoint(x: CGFloat(width), y: 0),
    options: []
)

// 3. Draw Windows Logo (4 White Squares)
context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))  // White

let centerX = CGFloat(width) / 2
let centerY = CGFloat(height) / 2
let gap: CGFloat = 30
let boxSize: CGFloat = 170

// Calculate rectangles
// Note: CoreGraphics origin is Bottom-Left.

// Top-Left Square (Visually) -> In CG (y is up), this is Top-Left (High Y)
let tlRect = CGRect(
    x: centerX - gap / 2 - boxSize, y: centerY + gap / 2, width: boxSize, height: boxSize)
// Top-Right Square
let trRect = CGRect(x: centerX + gap / 2, y: centerY + gap / 2, width: boxSize, height: boxSize)
// Bottom-Left Square
let blRect = CGRect(
    x: centerX - gap / 2 - boxSize, y: centerY - gap / 2 - boxSize, width: boxSize, height: boxSize)
// Bottom-Right Square
let brRect = CGRect(
    x: centerX + gap / 2, y: centerY - gap / 2 - boxSize, width: boxSize, height: boxSize)

context.addRects([tlRect, trRect, blRect, brRect])
context.fillPath()

// --- Saving ---

guard let image = context.makeImage() else {
    print("Failed to create CGImage")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
// "public.png" is the UTI for PNG
guard
    let destination = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil)
else {
    print("Failed to create image destination")
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
if CGImageDestinationFinalize(destination) {
    print("Successfully created icon at: \(outputPath)")
} else {
    print("Failed to write image file")
    exit(1)
}
