package com.muxy.app.features.demo

internal object DemoSwiftHighlighter {
    private val keywords =
        (
            "import final class struct enum func let var private fileprivate guard else return " +
                "if for in init self case switch throws try await async"
        ).split(" ").toSet()
    private val literals = setOf("true", "false", "nil")

    fun spans(line: String): List<DemoTerminalSpan> {
        val spans = mutableListOf<DemoTerminalSpan>()
        var index = 0
        while (index < line.length) {
            val character = line[index]
            val end =
                when {
                    character == '"' -> stringEnd(line, index)
                    character.isLetter() || character == '_' || character == '@' -> wordEnd(line, index)
                    character.isDigit() -> numberEnd(line, index)
                    else -> index + 1
                }
            val token = line.substring(index, end)
            spans += DemoTerminalSpan(token, style(token, isCall = end < line.length && line[end] == '('))
            index = end
        }
        return merged(spans)
    }

    private fun stringEnd(
        line: String,
        start: Int,
    ): Int {
        val closing = line.indexOf('"', start + 1)
        return if (closing < 0) line.length else closing + 1
    }

    private fun wordEnd(
        line: String,
        start: Int,
    ): Int {
        var end = start + 1
        while (end < line.length && (line[end].isLetterOrDigit() || line[end] == '_')) end++
        return end
    }

    private fun numberEnd(
        line: String,
        start: Int,
    ): Int {
        var end = start
        while (end < line.length && line[end].isDigit()) end++
        return end
    }

    private fun style(
        token: String,
        isCall: Boolean,
    ): String {
        val first = token.first()
        return when {
            first == '"' -> DemoStyle.GREEN
            first.isDigit() -> DemoStyle.CYAN
            first == '@' -> DemoStyle.YELLOW
            token in keywords -> DemoStyle.MAGENTA
            token in literals -> DemoStyle.CYAN
            first.isUpperCase() -> DemoStyle.YELLOW
            first.isLetter() && isCall -> DemoStyle.BLUE
            else -> DemoStyle.PLAIN
        }
    }

    private fun merged(spans: List<DemoTerminalSpan>): List<DemoTerminalSpan> =
        spans.fold(mutableListOf()) { result, span ->
            val last = result.lastOrNull()
            if (last != null && last.style == span.style) {
                result[result.lastIndex] = DemoTerminalSpan(last.text + span.text, last.style)
            } else {
                result += span
            }
            result
        }
}
