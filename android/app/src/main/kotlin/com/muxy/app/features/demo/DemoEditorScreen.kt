package com.muxy.app.features.demo

internal object DemoEditorScreen {
    private const val CURSOR_LINE = 24
    private const val GUTTER_WIDTH = 4
    private const val MAIN_FILE = "TabStore.swift"
    private const val SPLIT_FILE = "TabStoreTests.swift"

    fun render(canvas: DemoTerminalCanvas): String {
        val visibleRows = maxOf(canvas.rows - 2, 0)
        val source = lines(DemoSources.TAB_STORE)
        val footer = listOf(status(canvas), DemoTerminalLine("\"$MAIN_FILE\" ${source.size}L written", DemoStyle.DIM))
        val cursor = DemoTerminalCursor(minOf(CURSOR_LINE, maxOf(visibleRows, 1)), minOf(GUTTER_WIDTH + 6, canvas.cols))
        if (!canvas.isWide) return canvas.render(pane(source, canvas.cols, visibleRows, CURSOR_LINE) + footer, cursor)
        val leftWidth = (canvas.cols - 1) / 2
        val left = pane(source, leftWidth, visibleRows, CURSOR_LINE)
        val right = pane(lines(DemoSources.TAB_STORE_TESTS), canvas.cols - leftWidth - 1, visibleRows, null)
        val body = DemoTerminalCanvas.columns(left, leftWidth, DemoTerminalSpan("│", DemoStyle.DIM), right)
        return canvas.render(body + footer, cursor)
    }

    private fun lines(source: String): List<String> = source.split("\n").dropLast(1)

    private fun pane(
        source: List<String>,
        width: Int,
        rows: Int,
        cursorLine: Int?,
    ): List<DemoTerminalLine> {
        val codeWidth = maxOf(width - GUTTER_WIDTH - 1, 0)
        return List(rows) { index ->
            if (index >= source.size) return@List DemoTerminalLine("~", DemoStyle.BLUE)
            val number = index + 1
            val gutterStyle = if (number == cursorLine) DemoStyle.combined(DemoStyle.BOLD, DemoStyle.YELLOW) else DemoStyle.DIM
            val gutter = DemoTerminalSpan(number.toString().padStart(GUTTER_WIDTH - 1) + " ", gutterStyle)
            val code = DemoTerminalLine(DemoSwiftHighlighter.spans(source[index])).fitted(codeWidth)
            DemoTerminalLine(listOf(gutter, DemoTerminalSpan(" ")) + code.spans)
        }
    }

    private fun status(canvas: DemoTerminalCanvas): DemoTerminalLine {
        val fill = DemoStyle.combined("37", "100")
        val split = if (canvas.isWide) listOf(DemoTerminalSpan("│ $SPLIT_FILE ", fill)) else emptyList()
        return canvas.filled(
            listOf(
                DemoTerminalSpan(" NORMAL ", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.REVERSE, DemoStyle.GREEN)),
                DemoTerminalSpan(" $MAIN_FILE ", DemoStyle.combined(DemoStyle.BOLD, "97", "100")),
            ) + split,
            listOf(
                DemoTerminalSpan(" swift ", fill),
                DemoTerminalSpan(" $CURSOR_LINE:5 ", DemoStyle.combined(DemoStyle.REVERSE, DemoStyle.MAGENTA)),
            ),
            fill,
        )
    }
}
