package com.muxy.app.features.demo

internal object DemoStyle {
    const val PLAIN = ""
    const val BOLD = "1"
    const val DIM = "2"
    const val REVERSE = "7"
    const val RED = "31"
    const val GREEN = "32"
    const val YELLOW = "33"
    const val BLUE = "34"
    const val MAGENTA = "35"
    const val CYAN = "36"
    const val BRIGHT_WHITE = "97"

    fun combined(vararg codes: String): String = codes.filter { it.isNotEmpty() }.joinToString(";")
}

internal data class DemoTerminalSpan(
    val text: String,
    val style: String = DemoStyle.PLAIN,
)

internal data class DemoTerminalLine(
    val spans: List<DemoTerminalSpan>,
) {
    constructor(text: String, style: String = DemoStyle.PLAIN) : this(listOf(DemoTerminalSpan(text, style)))

    val width: Int get() = spans.sumOf { it.text.length }

    fun fitted(cols: Int): DemoTerminalLine {
        var remaining = cols
        val fitted = mutableListOf<DemoTerminalSpan>()
        for (span in spans) {
            if (remaining <= 0) break
            val text = span.text.take(remaining)
            fitted += DemoTerminalSpan(text, span.style)
            remaining -= text.length
        }
        return DemoTerminalLine(fitted)
    }

    fun padded(cols: Int): DemoTerminalLine {
        val fitted = fitted(cols)
        val padding = cols - fitted.width
        if (padding <= 0) return fitted
        return DemoTerminalLine(fitted.spans + DemoTerminalSpan(" ".repeat(padding)))
    }

    fun appending(more: List<DemoTerminalSpan>): DemoTerminalLine = DemoTerminalLine(spans + more)

    val encoded: String
        get() =
            spans.joinToString("") { span ->
                if (span.style.isEmpty()) span.text else "$ESCAPE[${span.style}m${span.text}$ESCAPE[0m"
            }

    companion object {
        val BLANK = DemoTerminalLine(emptyList())
        const val ESCAPE = "\u001B"
    }
}

internal data class DemoTerminalCursor(
    val row: Int,
    val col: Int,
)

internal data class DemoTerminalCanvas(
    val cols: Int,
    val rows: Int,
) {
    val isWide: Boolean get() = cols >= WIDE_LAYOUT_COLUMNS

    fun justified(
        left: List<DemoTerminalSpan>,
        right: List<DemoTerminalSpan>,
    ): DemoTerminalLine {
        val gap = cols - 1 - DemoTerminalLine(left).width - DemoTerminalLine(right).width
        if (gap < 2) return DemoTerminalLine(left)
        return DemoTerminalLine(left + DemoTerminalSpan(" ".repeat(gap)) + right)
    }

    fun filled(
        left: List<DemoTerminalSpan>,
        right: List<DemoTerminalSpan>,
        fillStyle: String,
    ): DemoTerminalLine {
        val gap = maxOf(0, cols - DemoTerminalLine(left).width - DemoTerminalLine(right).width)
        return DemoTerminalLine(left + DemoTerminalSpan(" ".repeat(gap), fillStyle) + right).fitted(cols)
    }

    fun compose(
        body: List<DemoTerminalLine>,
        footer: List<DemoTerminalLine> = emptyList(),
    ): List<DemoTerminalLine> {
        val bodyRows = maxOf(0, rows - footer.size)
        val visibleBody = body.takeLast(bodyRows)
        val padding = List(bodyRows - visibleBody.size) { DemoTerminalLine.BLANK }
        return visibleBody + padding + footer.takeLast(rows)
    }

    fun render(
        body: List<DemoTerminalLine>,
        footer: List<DemoTerminalLine> = emptyList(),
        cursor: DemoTerminalCursor? = null,
    ): String {
        val visibleBodyCount = minOf(body.size, maxOf(0, rows - footer.size))
        return render(compose(body, footer), cursor ?: DemoTerminalCursor(minOf(visibleBodyCount + 1, rows), 1))
    }

    fun render(
        lines: List<DemoTerminalLine>,
        cursor: DemoTerminalCursor,
    ): String {
        val escape = DemoTerminalLine.ESCAPE
        val screen = lines.take(rows).joinToString("\r\n") { it.fitted(cols).encoded }
        return "$escape[0m$escape[H$escape[2J$screen$escape[${cursor.row};${cursor.col}H"
    }

    companion object {
        const val WIDE_LAYOUT_COLUMNS = 120

        fun columns(
            left: List<DemoTerminalLine>,
            width: Int,
            separator: DemoTerminalSpan,
            right: List<DemoTerminalLine>,
        ): List<DemoTerminalLine> =
            List(maxOf(left.size, right.size)) { index ->
                val leftLine = left.getOrElse(index) { DemoTerminalLine.BLANK }
                val rightLine = right.getOrElse(index) { DemoTerminalLine.BLANK }
                leftLine.padded(width).appending(listOf(separator) + rightLine.spans)
            }

        fun wrap(
            text: String,
            width: Int,
        ): List<String> {
            if (width <= 0) return listOf(text)
            val lines = mutableListOf<String>()
            var current = ""
            for (word in text.split(" ")) {
                val candidate = if (current.isEmpty()) word else "$current $word"
                if (candidate.length <= width) {
                    current = candidate
                    continue
                }
                if (current.isNotEmpty()) lines += current
                current = word
                while (current.length > width) {
                    lines += current.take(width)
                    current = current.drop(width)
                }
            }
            lines += current
            return lines
        }
    }
}
