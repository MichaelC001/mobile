package com.muxy.app.features.demo

internal enum class DemoTerminalScreen {
    SHELL,
    AGENT,
    EDITOR,
    DEV_SERVER,
    ;

    val redrawsOnResize: Boolean get() = this != SHELL

    fun render(
        cols: Int,
        rows: Int,
    ): String {
        val canvas = DemoTerminalCanvas(maxOf(cols, 1), maxOf(rows, 1))
        return when (this) {
            SHELL -> DemoShell.BANNER + DemoShell.PROMPT
            AGENT -> DemoAgentScreen.render(canvas)
            EDITOR -> DemoEditorScreen.render(canvas)
            DEV_SERVER -> DemoDevServerScreen.render(canvas)
        }
    }
}
