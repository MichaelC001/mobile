import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum RenderError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(name): "Could not render \(name)"
        }
    }
}

@MainActor
enum Renderer {
    static func write(_ view: some View, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else { throw RenderError.failed(url.lastPathComponent) }
        try writeOpaquePNG(image, to: url)
    }

    private static func writeOpaquePNG(_ image: CGImage, to url: URL) throws {
        guard
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { throw RenderError.failed(url.lastPathComponent) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard
            let flattened = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw RenderError.failed(url.lastPathComponent) }
        CGImageDestinationAddImage(destination, flattened, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.failed(url.lastPathComponent) }
    }
}
