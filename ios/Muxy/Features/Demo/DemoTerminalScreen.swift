import Foundation

nonisolated enum DemoTerminalScreen: Sendable, Equatable {
    case shell
    case agent
    case editor
    case devServer

    var redrawsOnResize: Bool {
        self != .shell
    }

    func render(cols: Int, rows: Int) -> String {
        let canvas = DemoTerminalCanvas(cols: max(cols, 1), rows: max(rows, 1))
        switch self {
        case .shell:
            return Self.shellText
        case .agent:
            return DemoAgentScreen.render(on: canvas)
        case .editor:
            return DemoEditorScreen.render(on: canvas)
        case .devServer:
            return DemoDevServerScreen.render(on: canvas)
        }
    }

    private static let shellText = "\u{001B}[1;32mDemo Mode\u{001B}[0m - this terminal is simulated.\r\nType any command and press Enter to see the demo response.\r\ndemo@muxy ~ % "
}
