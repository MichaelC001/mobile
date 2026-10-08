import Foundation

nonisolated enum DemoDevServerScreen {
    static func render(on canvas: DemoTerminalCanvas) -> String {
        let body: [DemoTerminalLine] = [
            DemoTerminalLine([DemoTerminalSpan("demo@muxy web-app % ", DemoStyle.dim), DemoTerminalSpan("npm run dev")]),
            .blank,
            DemoTerminalLine("> web-app@2.3.0 dev", DemoStyle.dim),
            DemoTerminalLine("> vite --host", DemoStyle.dim),
            .blank,
            DemoTerminalLine([
                DemoTerminalSpan("  VITE v6.2.0", DemoStyle.combined(DemoStyle.bold, DemoStyle.green)),
                DemoTerminalSpan("  ready in ", DemoStyle.dim),
                DemoTerminalSpan("412 ms", DemoStyle.bold)
            ]),
            .blank,
            serverAddress("Local:", "http://localhost:5173/"),
            serverAddress("Network:", "http://192.168.1.24:5173/"),
            .blank,
            hotUpdate("09:38:02", "src/routes/settings.tsx"),
            hotUpdate("09:39:47", "src/components/TabBar.tsx"),
            hotUpdate("09:40:15", "src/components/TabBar.tsx"),
            DemoTerminalLine([
                DemoTerminalSpan("09:41:03 ", DemoStyle.dim),
                DemoTerminalSpan("[vite] ", DemoStyle.combined(DemoStyle.bold, DemoStyle.cyan)),
                DemoTerminalSpan("page reload ", DemoStyle.green),
                DemoTerminalSpan("src/main.tsx", DemoStyle.dim)
            ])
        ]
        return canvas.render(body: body)
    }

    private static func serverAddress(_ label: String, _ url: String) -> DemoTerminalLine {
        DemoTerminalLine([
            DemoTerminalSpan("  ➜  ", DemoStyle.green),
            DemoTerminalSpan(label.padding(toLength: 9, withPad: " ", startingAt: 0), DemoStyle.bold),
            DemoTerminalSpan(url, DemoStyle.cyan)
        ])
    }

    private static func hotUpdate(_ time: String, _ path: String) -> DemoTerminalLine {
        DemoTerminalLine([
            DemoTerminalSpan("\(time) ", DemoStyle.dim),
            DemoTerminalSpan("[vite] ", DemoStyle.combined(DemoStyle.bold, DemoStyle.cyan)),
            DemoTerminalSpan("hmr update ", DemoStyle.green),
            DemoTerminalSpan("/\(path)", DemoStyle.dim)
        ])
    }
}
