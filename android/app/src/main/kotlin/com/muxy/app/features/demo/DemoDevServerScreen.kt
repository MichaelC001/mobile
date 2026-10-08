package com.muxy.app.features.demo

internal object DemoDevServerScreen {
    private const val LABEL_WIDTH = 9

    fun render(canvas: DemoTerminalCanvas): String =
        canvas.render(
            listOf(
                DemoTerminalLine(listOf(DemoTerminalSpan("demo@muxy web-app % ", DemoStyle.DIM), DemoTerminalSpan("npm run dev"))),
                DemoTerminalLine.BLANK,
                DemoTerminalLine("> web-app@2.3.0 dev", DemoStyle.DIM),
                DemoTerminalLine("> vite --host", DemoStyle.DIM),
                DemoTerminalLine.BLANK,
                DemoTerminalLine(
                    listOf(
                        DemoTerminalSpan("  VITE v6.2.0", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.GREEN)),
                        DemoTerminalSpan("  ready in ", DemoStyle.DIM),
                        DemoTerminalSpan("412 ms", DemoStyle.BOLD),
                    ),
                ),
                DemoTerminalLine.BLANK,
                serverAddress("Local:", "http://localhost:5173/"),
                serverAddress("Network:", "http://192.168.1.24:5173/"),
                DemoTerminalLine.BLANK,
                hotUpdate("09:38:02", "src/routes/settings.tsx"),
                hotUpdate("09:39:47", "src/components/TabBar.tsx"),
                hotUpdate("09:40:15", "src/components/TabBar.tsx"),
                DemoTerminalLine(
                    listOf(
                        DemoTerminalSpan("09:41:03 ", DemoStyle.DIM),
                        DemoTerminalSpan("[vite] ", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.CYAN)),
                        DemoTerminalSpan("page reload ", DemoStyle.GREEN),
                        DemoTerminalSpan("src/main.tsx", DemoStyle.DIM),
                    ),
                ),
            ),
        )

    private fun serverAddress(
        label: String,
        url: String,
    ) = DemoTerminalLine(
        listOf(
            DemoTerminalSpan("  ➜  ", DemoStyle.GREEN),
            DemoTerminalSpan(label.padEnd(LABEL_WIDTH), DemoStyle.BOLD),
            DemoTerminalSpan(url, DemoStyle.CYAN),
        ),
    )

    private fun hotUpdate(
        time: String,
        path: String,
    ) = DemoTerminalLine(
        listOf(
            DemoTerminalSpan("$time ", DemoStyle.DIM),
            DemoTerminalSpan("[vite] ", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.CYAN)),
            DemoTerminalSpan("hmr update ", DemoStyle.GREEN),
            DemoTerminalSpan("/$path", DemoStyle.DIM),
        ),
    )
}
