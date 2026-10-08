import Foundation

nonisolated enum DemoEditorScreen {
    private static let cursorLine = 24
    private static let gutterWidth = 4
    private static let mainFile = "TabStore.swift"
    private static let splitFile = "TabStoreTests.swift"

    static func render(on canvas: DemoTerminalCanvas) -> String {
        let visibleRows = max(canvas.rows - 2, 0)
        let source = lines(of: DemoSources.tabStore)
        let footer = [status(on: canvas), DemoTerminalLine("\"\(mainFile)\" \(source.count)L written", DemoStyle.dim)]
        let cursor = DemoTerminalCursor(row: min(cursorLine, max(visibleRows, 1)), col: min(gutterWidth + 6, canvas.cols))
        guard canvas.isWide else {
            let body = pane(source, width: canvas.cols, rows: visibleRows, cursorLine: cursorLine)
            return canvas.render(body + footer, cursor: cursor)
        }
        let leftWidth = (canvas.cols - 1) / 2
        let left = pane(source, width: leftWidth, rows: visibleRows, cursorLine: cursorLine)
        let right = pane(lines(of: DemoSources.tabStoreTests), width: canvas.cols - leftWidth - 1, rows: visibleRows, cursorLine: nil)
        let body = DemoTerminalCanvas.columns(left, width: leftWidth, separator: DemoTerminalSpan("│", DemoStyle.dim), right)
        return canvas.render(body + footer, cursor: cursor)
    }

    private static func lines(of source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
    }

    private static func pane(_ source: [String], width: Int, rows: Int, cursorLine: Int?) -> [DemoTerminalLine] {
        let codeWidth = max(width - gutterWidth - 1, 0)
        return (0..<rows).map { index in
            guard index < source.count else { return DemoTerminalLine("~", DemoStyle.blue) }
            let number = index + 1
            let gutterStyle = number == cursorLine ? DemoStyle.combined(DemoStyle.bold, DemoStyle.yellow) : DemoStyle.dim
            let gutter = DemoTerminalSpan(String(number).leftPadded(to: gutterWidth - 1) + " ", gutterStyle)
            let code = DemoTerminalLine(DemoSwiftHighlighter.spans(for: source[index])).fitted(to: codeWidth)
            return DemoTerminalLine([gutter, DemoTerminalSpan(" ")] + code.spans)
        }
    }

    private static func status(on canvas: DemoTerminalCanvas) -> DemoTerminalLine {
        let fill = DemoStyle.combined("37", "100")
        var left = [
            DemoTerminalSpan(" NORMAL ", DemoStyle.combined(DemoStyle.bold, DemoStyle.reverse, DemoStyle.green)),
            DemoTerminalSpan(" \(mainFile) ", DemoStyle.combined(DemoStyle.bold, "97", "100"))
        ]
        if canvas.isWide { left.append(DemoTerminalSpan("│ \(splitFile) ", fill)) }
        return canvas.filled(
            left,
            [
                DemoTerminalSpan(" swift ", fill),
                DemoTerminalSpan(" \(cursorLine):5 ", DemoStyle.combined(DemoStyle.reverse, DemoStyle.magenta))
            ],
            fillStyle: fill
        )
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: " ", count: max(width - count, 0)) + self
    }
}
