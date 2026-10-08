import AppKit
import SwiftUI

struct SlideView: View {
    let slide: Slide
    let index: Int
    let target: StoreTarget
    let images: [String: NSImage]

    private var canvas: CGSize { target.canvas }
    private var margin: CGFloat { min(canvas.width, canvas.height) * 0.03 }

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(canvas: canvas, index: index)
            VStack(spacing: 0) {
                Headline(slide: slide, target: target)
                    .padding(.top, canvas.height * 0.052)
                GeometryReader { proxy in
                    devices(in: proxy.size)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }

    @ViewBuilder
    private func devices(in box: CGSize) -> some View {
        let area = CGSize(width: box.width, height: box.height - margin * 2.2)
        switch slide.layout {
        case let .single(shot):
            single(screen(shot), in: area)
        case let .bands(shots):
            single(BandedScreen(images: shots.map(image), kind: target.device), in: area)
        case let .pair(front, back):
            pair(front: screen(front), back: screen(back), in: area)
        }
    }

    private func single(_ content: some View, in area: CGSize) -> some View {
        let geometry = DeviceGeometry.fitting(target.device, in: CGSize(width: area.width * 0.76, height: area.height))
        return ZStack(alignment: .topLeading) {
            glow(behind: geometry)
                .offset(x: (area.width - geometry.size.width) / 2, y: margin * 1.6)
            framed(content, geometry: geometry)
                .offset(x: (area.width - geometry.size.width) / 2, y: margin * 1.6)
        }
        .frame(width: area.width, height: area.height + margin * 2.2, alignment: .topLeading)
    }

    private func pair(front: some View, back: some View, in area: CGSize) -> some View {
        let frontGeometry = DeviceGeometry.fitting(target.device, in: CGSize(width: area.width * 0.70, height: area.height))
        let backGeometry = frontGeometry.scaled(0.88)
        let frontX = area.width - frontGeometry.size.width - margin * 0.8
        let backY = margin * 1.6 + frontGeometry.size.height * 0.08
        return ZStack(alignment: .topLeading) {
            framed(back, geometry: backGeometry)
                .offset(x: margin * 0.8, y: backY)
            glow(behind: frontGeometry)
                .offset(x: frontX, y: margin * 1.6)
            framed(front, geometry: frontGeometry)
                .offset(x: frontX, y: margin * 1.6)
        }
        .frame(width: area.width, height: area.height + margin * 2.2, alignment: .topLeading)
    }

    private func screen(_ shot: String) -> some View {
        Image(nsImage: image(shot)).resizable().interpolation(.high)
    }

    private func image(_ shot: String) -> NSImage {
        guard let image = images[shot] else { fatalError("Missing capture '\(shot)' for \(target.rawValue)") }
        return image
    }

    private func framed(_ content: some View, geometry: DeviceGeometry) -> some View {
        DeviceFrame(geometry: geometry, screen: content)
            .shadow(color: .black.opacity(0.55), radius: geometry.size.width * 0.06, x: 0, y: geometry.size.width * 0.04)
    }

    private func glow(behind geometry: DeviceGeometry) -> some View {
        RoundedRectangle(cornerRadius: geometry.outerRadius * 1.2, style: .continuous)
            .fill(Brand.glow)
            .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.85)
            .blur(radius: min(geometry.size.width, geometry.size.height) * 0.14)
            .opacity(0.45)
            .offset(x: geometry.size.width * 0.05, y: geometry.size.height * 0.08)
    }
}

struct BandedScreen: View {
    let images: [NSImage]
    let kind: DeviceKind

    private var size: CGSize { kind.screenSize }
    private var slant: CGFloat { min(size.width, size.height) * 0.42 }

    var body: some View {
        ZStack {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                Image(nsImage: image)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .clipShape(BandShape(index: index, count: images.count, slant: slant))
            }
            BandEdges(count: images.count, slant: slant)
                .stroke(Color.white.opacity(0.85), lineWidth: min(size.width, size.height) * 0.004)
                .shadow(color: Brand.violet, radius: min(size.width, size.height) * 0.014)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct BandShape: Shape {
    let index: Int
    let count: Int
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        let step = (rect.height + slant) / CGFloat(count)
        let top = CGFloat(index) * step
        let bottom = CGFloat(index + 1) * step
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: top - slant))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom - slant))
        path.addLine(to: CGPoint(x: rect.minX, y: bottom))
        path.closeSubpath()
        return path
    }
}

struct BandEdges: Shape {
    let count: Int
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        let step = (rect.height + slant) / CGFloat(count)
        var path = Path()
        for index in 1..<count {
            let y = CGFloat(index) * step
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y - slant))
        }
        return path
    }
}
