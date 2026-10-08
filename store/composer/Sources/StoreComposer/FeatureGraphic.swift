import AppKit
import SwiftUI

struct FeatureGraphic: View {
    static let canvas = CGSize(width: 1024, height: 500)

    let icon: NSImage
    let screenshot: NSImage

    var body: some View {
        let geometry = DeviceGeometry(kind: .pixelPhone, screenWidth: 270)
        ZStack(alignment: .topLeading) {
            Backdrop(canvas: Self.canvas, index: 0)
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                    Text("Muxy")
                        .font(.system(size: 66, weight: .bold))
                        .tracking(-1.2)
                        .foregroundStyle(Brand.text)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Mac terminal.")
                        .foregroundStyle(Brand.text)
                    Text("In your pocket.")
                        .foregroundStyle(Brand.gradient)
                }
                .font(.system(size: 44, weight: .bold))
                .tracking(-0.8)
                Text("Coding agents, git and files, wherever you are.")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Brand.muted)
            }
            .padding(.leading, 64)
            .padding(.top, 78)
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(Brand.glow)
                .frame(width: 260, height: 420)
                .blur(radius: 60)
                .opacity(0.5)
                .rotationEffect(.degrees(-8))
                .offset(x: 700, y: 90)
            DeviceFrame(geometry: geometry, screen: Image(nsImage: screenshot).resizable().interpolation(.high))
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.6), radius: 30, y: 18)
                .offset(x: 690, y: 44)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
        .clipped()
    }
}
