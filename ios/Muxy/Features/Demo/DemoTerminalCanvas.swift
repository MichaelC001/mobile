import Foundation

nonisolated enum DemoStyle {
    static let plain = ""
    static let bold = "1"
    static let dim = "2"
    static let reverse = "7"
    static let red = "31"
    static let green = "32"
    static let yellow = "33"
    static let blue = "34"
    static let magenta = "35"
    static let cyan = "36"
    static let brightWhite = "97"

    static func combined(_ codes: String...) -> String {
        codes.filter { !$0.isEmpty }.joined(separator: ";")
    }
}

nonisolated struct DemoTerminalSpan: Sendable, Equatable {
    let text: String
    let style: String

    init(_ text: String, _ style: String = DemoStyle.plain) {
        self.text = text
        self.style = style
    }
}

nonisolated struct DemoTerminalLine: Sendable, Equatable {
    let spans: [DemoTerminalSpan]

    static let blank = DemoTerminalLine([])

    init(_ spans: [DemoTerminalSpan]) {
        self.spans = spans
    }

    init(_ text: String, _ style: String = DemoStyle.plain) {
        spans = [DemoTerminalSpan(text, style)]
    }

    var width: Int {
        spans.reduce(0) { $0 + $1.text.count }
    }

    func fitted(to cols: Int) -> DemoTerminalLine {
        var remaining = cols
        var fitted: [DemoTerminalSpan] = []
        for span in spans where remaining > 0 {
            let text = String(span.text.prefix(remaining))
            fitted.append(DemoTerminalSpan(text, span.style))
            remaining -= text.count
        }
        return DemoTerminalLine(fitted)
    }

    func padded(to cols: Int) -> DemoTerminalLine {
        let fitted = fitted(to: cols)
        let padding = cols - fitted.width
        guard padding > 0 else { return fitted }
        return DemoTerminalLine(fitted.spans + [DemoTerminalSpan(String(repeating: " ", count: padding))])
    }

    func appending(_ spans: [DemoTerminalSpan]) -> DemoTerminalLine {
        DemoTerminalLine(self.spans + spans)
    }

    var encoded: String {
        spans.map { span in
            guard !span.style.isEmpty else { return span.text }
            return "\u{1B}[\(span.style)m\(span.text)\u{1B}[0m"
        }.joined()
    }
}

nonisolated struct DemoTerminalCursor: Sendable, Equatable {
    let row: Int
    let col: Int
}

nonisolated struct DemoTerminalCanvas: Sendable {
    static let wideLayoutColumns = 120

    let cols: Int
    let rows: Int

    var isWide: Bool {
        cols >= Self.wideLayoutColumns
    }

    func justified(_ left: [DemoTerminalSpan], _ right: [DemoTerminalSpan]) -> DemoTerminalLine {
        let leftWidth = DemoTerminalLine(left).width
        let rightWidth = DemoTerminalLine(right).width
        let gap = cols - 1 - leftWidth - rightWidth
        guard gap >= 2 else { return DemoTerminalLine(left) }
        return DemoTerminalLine(left + [DemoTerminalSpan(String(repeating: " ", count: gap))] + right)
    }

    func filled(_ left: [DemoTerminalSpan], _ right: [DemoTerminalSpan], fillStyle: String) -> DemoTerminalLine {
        let leftWidth = DemoTerminalLine(left).width
        let rightWidth = DemoTerminalLine(right).width
        let gap = max(0, cols - leftWidth - rightWidth)
        let fill = DemoTerminalSpan(String(repeating: " ", count: gap), fillStyle)
        return DemoTerminalLine(left + [fill] + right).fitted(to: cols)
    }

    func compose(body: [DemoTerminalLine], footer: [DemoTerminalLine] = []) -> [DemoTerminalLine] {
        let bodyRows = max(0, rows - footer.count)
        let visibleBody = Array(body.suffix(bodyRows))
        let padding = Array(repeating: DemoTerminalLine.blank, count: bodyRows - visibleBody.count)
        return visibleBody + padding + footer.suffix(rows)
    }

    func render(body: [DemoTerminalLine], footer: [DemoTerminalLine] = [], cursor: DemoTerminalCursor? = nil) -> String {
        let visibleBodyCount = min(body.count, max(0, rows - footer.count))
        let resolvedCursor = cursor ?? DemoTerminalCursor(row: min(visibleBodyCount + 1, rows), col: 1)
        return render(compose(body: body, footer: footer), cursor: resolvedCursor)
    }

    func render(_ lines: [DemoTerminalLine], cursor: DemoTerminalCursor) -> String {
        "\u{1B}[0m\u{1B}[H\u{1B}[2J"
            + lines.prefix(rows).map { $0.fitted(to: cols).encoded }.joined(separator: "\r\n")
            + "\u{1B}[\(cursor.row);\(cursor.col)H"
    }

    static func columns(
        _ left: [DemoTerminalLine],
        width: Int,
        separator: DemoTerminalSpan,
        _ right: [DemoTerminalLine]
    ) -> [DemoTerminalLine] {
        (0..<max(left.count, right.count)).map { index in
            let leftLine = index < left.count ? left[index] : .blank
            let rightLine = index < right.count ? right[index] : .blank
            return leftLine.padded(to: width).appending([separator] + rightLine.spans)
        }
    }

    static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [text] }
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false).map(String.init) {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count <= width {
                current = candidate
                continue
            }
            if !current.isEmpty { lines.append(current) }
            current = word
            while current.count > width {
                lines.append(String(current.prefix(width)))
                current = String(current.dropFirst(width))
            }
        }
        lines.append(current)
        return lines
    }
}
