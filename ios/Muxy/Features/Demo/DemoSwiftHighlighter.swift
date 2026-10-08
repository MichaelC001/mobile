import Foundation

nonisolated enum DemoSwiftHighlighter {
    private static let keywords: Set<String> = [
        "import", "final", "class", "struct", "enum", "func", "let", "var", "private", "fileprivate",
        "guard", "else", "return", "if", "for", "in", "init", "self", "case", "switch", "throws", "try", "await", "async"
    ]
    private static let literals: Set<String> = ["true", "false", "nil"]

    static func spans(for line: String) -> [DemoTerminalSpan] {
        var spans: [DemoTerminalSpan] = []
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let end = line[line.index(after: index)...].firstIndex(of: "\"").map { line.index(after: $0) } ?? line.endIndex
                spans.append(DemoTerminalSpan(String(line[index..<end]), DemoStyle.green))
                index = end
                continue
            }
            if character.isLetter || character == "_" || character == "@" {
                let end = line[line.index(after: index)...].firstIndex { !($0.isLetter || $0.isNumber || $0 == "_") } ?? line.endIndex
                let word = String(line[index..<end])
                let isCall = end < line.endIndex && line[end] == "("
                spans.append(DemoTerminalSpan(word, style(forWord: word, isCall: isCall)))
                index = end
                continue
            }
            if character.isNumber {
                let end = line[index...].firstIndex { !$0.isNumber } ?? line.endIndex
                spans.append(DemoTerminalSpan(String(line[index..<end]), DemoStyle.cyan))
                index = end
                continue
            }
            spans.append(DemoTerminalSpan(String(character)))
            index = line.index(after: index)
        }
        return merged(spans)
    }

    private static func style(forWord word: String, isCall: Bool) -> String {
        if word.hasPrefix("@") { return DemoStyle.yellow }
        if keywords.contains(word) { return DemoStyle.magenta }
        if literals.contains(word) { return DemoStyle.cyan }
        if word.first?.isUppercase == true { return DemoStyle.yellow }
        if isCall { return DemoStyle.blue }
        return DemoStyle.plain
    }

    private static func merged(_ spans: [DemoTerminalSpan]) -> [DemoTerminalSpan] {
        spans.reduce(into: []) { result, span in
            guard let last = result.last, last.style == span.style else {
                result.append(span)
                return
            }
            result[result.count - 1] = DemoTerminalSpan(last.text + span.text, last.style)
        }
    }
}
