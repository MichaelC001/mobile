import SwiftUI

struct Backdrop: View {
    let canvas: CGSize
    let index: Int

    private struct Glow {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let color: Color
        let opacity: Double
    }

    private struct Chevron {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private static let glows: [Glow] = [
        Glow(x: 0.091, y: 0.181, radius: 0.384, color: Brand.blue, opacity: 0.38),
        Glow(x: 0.947, y: 0.662, radius: 0.401, color: Brand.violet, opacity: 0.34),
        Glow(x: 1.553, y: 0.157, radius: 0.349, color: Brand.pink, opacity: 0.26),
        Glow(x: 2.197, y: 0.767, radius: 0.418, color: Brand.cyan, opacity: 0.26),
        Glow(x: 2.803, y: 0.244, radius: 0.384, color: Brand.violet, opacity: 0.34),
        Glow(x: 3.409, y: 0.732, radius: 0.401, color: Brand.pink, opacity: 0.28),
        Glow(x: 4.053, y: 0.174, radius: 0.384, color: Brand.blue, opacity: 0.36),
        Glow(x: 4.697, y: 0.697, radius: 0.401, color: Brand.violet, opacity: 0.32),
        Glow(x: 5.303, y: 0.209, radius: 0.349, color: Brand.cyan, opacity: 0.26),
        Glow(x: 5.985, y: 0.732, radius: 0.401, color: Brand.pink, opacity: 0.30),
        Glow(x: 6.667, y: 0.227, radius: 0.384, color: Brand.blue, opacity: 0.34)
    ]

    private static let chevrons: [Chevron] = [
        Chevron(x: 1.0, y: 0.523, size: 0.906, opacity: 0.07),
        Chevron(x: 3.0, y: 0.558, size: 0.837, opacity: 0.06),
        Chevron(x: 5.0, y: 0.506, size: 0.906, opacity: 0.07),
        Chevron(x: 7.0, y: 0.558, size: 0.837, opacity: 0.06)
    ]

    var body: some View {
        let unit = max(canvas.width, canvas.height)
        let offset = CGFloat(index) * canvas.width
        ZStack {
            Brand.background
            ForEach(Array(Self.glows.enumerated()), id: \.offset) { _, glow in
                RadialGradient(
                    colors: [glow.color.opacity(glow.opacity), glow.color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: glow.radius * unit
                )
                .frame(width: glow.radius * unit * 2, height: glow.radius * unit * 2)
                .position(x: glow.x * canvas.width - offset, y: glow.y * canvas.height)
            }
            ForEach(Array(Self.chevrons.enumerated()), id: \.offset) { _, chevron in
                let height = chevron.size * canvas.height
                ChevronShape()
                    .stroke(
                        LinearGradient(colors: [Brand.cyan, Brand.violet, Brand.pink], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: height * 0.11, lineCap: .butt, lineJoin: .miter)
                    )
                    .frame(width: height * 0.62, height: height)
                    .opacity(chevron.opacity)
                    .position(x: chevron.x * canvas.width - offset, y: chevron.y * canvas.height)
            }
            LinearGradient(colors: [Brand.background.opacity(0), Brand.background.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
