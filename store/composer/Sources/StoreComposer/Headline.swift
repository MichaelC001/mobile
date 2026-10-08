import SwiftUI

struct Headline: View {
    let slide: Slide
    let target: StoreTarget

    private var base: CGFloat {
        min(target.canvas.width, target.canvas.height * 0.46)
    }

    private var eyebrowSize: CGFloat { base * 0.0303 }
    private var titleSize: CGFloat { base * 0.097 }
    private var subtitleSize: CGFloat { base * 0.0379 }
    private var spacing: CGFloat { base * 0.0258 }

    var body: some View {
        VStack(spacing: spacing) {
            Text(slide.eyebrow.uppercased())
                .font(.system(size: eyebrowSize, weight: .bold))
                .tracking(eyebrowSize * 0.22)
                .foregroundStyle(Brand.gradient)
            VStack(spacing: 2) {
                ForEach(slide.title, id: \.self) { line in
                    titleLine(line)
                }
            }
            Text(slide.subtitle)
                .font(.system(size: subtitleSize, weight: .regular))
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(subtitleSize * 0.16)
                .frame(maxWidth: base * 0.82)
        }
    }

    private func titleLine(_ line: String) -> some View {
        let parts = line.components(separatedBy: slide.highlight)
        return HStack(spacing: 0) {
            if parts.count == 2 {
                Text(parts[0]).foregroundStyle(Brand.text)
                Text(slide.highlight).foregroundStyle(Brand.gradient)
                Text(parts[1]).foregroundStyle(Brand.text)
            } else {
                Text(line).foregroundStyle(Brand.text)
            }
        }
        .font(.system(size: titleSize, weight: .bold))
        .tracking(-titleSize * 0.02)
        .lineLimit(1)
    }
}
