import Foundation

nonisolated enum DemoAgentScreen {
    private static let prompt = "Open a pull request"
    private static let sidebarWidth = 38
    private static let sidebarGap = 2

    static func render(on canvas: DemoTerminalCanvas) -> String {
        guard canvas.isWide else {
            return canvas.render(body: transcript(on: canvas), footer: input(on: canvas), cursor: cursor(on: canvas))
        }
        let conversation = DemoTerminalCanvas(cols: canvas.cols - sidebarWidth - sidebarGap, rows: canvas.rows)
        let left = conversation.compose(body: transcript(on: conversation), footer: input(on: conversation))
        let lines = DemoTerminalCanvas.columns(
            left,
            width: conversation.cols,
            separator: DemoTerminalSpan(String(repeating: " ", count: sidebarGap)),
            sidebar()
        )
        return canvas.render(lines, cursor: cursor(on: conversation))
    }

    private static func cursor(on canvas: DemoTerminalCanvas) -> DemoTerminalCursor {
        DemoTerminalCursor(row: max(canvas.rows - 2, 1), col: min(prompt.count + 6, canvas.cols))
    }

    private static func transcript(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        header() + history(on: canvas) + rebase(on: canvas) + testRun(on: canvas) + question(on: canvas) + task(on: canvas) + summary(on: canvas)
    }

    private static func header() -> [DemoTerminalLine] {
        [
            DemoTerminalLine([
                DemoTerminalSpan(" ◆ agent", DemoStyle.combined(DemoStyle.bold, DemoStyle.magenta)),
                DemoTerminalSpan("  ~/Projects/muxy", DemoStyle.dim)
            ]),
            .blank
        ]
    }

    private static func history(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = userMessage("What landed on main since yesterday?", on: canvas)
        lines += [
            .blank,
            toolCall("Run", "git log --oneline origin/main@{1.day.ago}..", on: canvas),
            toolResult("✓ 5 commits", detail: "")
        ]
        lines += [
            commit("a41f2c9", "Fix split pane focus after closing a tab"),
            commit("9be03d1", "Add worktree picker to the command palette"),
            commit("77c5e10", "Speed up project list loading"),
            commit("3d0b8aa", "Keep scrollback when a pane is resized"),
            commit("e52f4c7", "Show branch ahead and behind counts"),
            .blank
        ]
        lines += paragraph("Mostly worktree and split pane fixes. Nothing touches TabStore yet.", on: canvas)
        lines.append(.blank)
        return lines
    }

    private static func commit(_ hash: String, _ message: String) -> DemoTerminalLine {
        DemoTerminalLine([
            DemoTerminalSpan("     \(hash) ", DemoStyle.yellow),
            DemoTerminalSpan(message, DemoStyle.dim)
        ])
    }

    private static func rebase(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = userMessage("Pull the latest main and rebase my branch", on: canvas)
        lines += [
            .blank,
            toolCall("Run", "git pull --rebase origin main", on: canvas),
            toolResult("✓ Rebased 3 commits onto main", detail: ""),
            .blank
        ]
        lines += paragraph("Your branch is up to date with origin/main and 3 commits ahead.", on: canvas)
        lines.append(.blank)
        return lines
    }

    private static func testRun(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = userMessage("Run the full test suite", on: canvas)
        lines += [
            .blank,
            toolCall("Run", "swift test", on: canvas),
            toolResult("✓ 214 tests passed", detail: " in 8.4s"),
            .blank
        ]
        lines += paragraph("All green. The slowest suite is WorktreeTests at 2.1s.", on: canvas)
        lines.append(.blank)
        return lines
    }

    private static func question(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = userMessage("How are tabs closed today?", on: canvas)
        lines += [.blank, toolCall("Search", "\"closeTab\"", detail: "6 matches", on: canvas), .blank]
        lines += paragraph("TabStore.close(_:) removes the tab and focuses its neighbour. Closed tabs are discarded, so there is no way to bring one back.", on: canvas)
        lines.append(.blank)
        return lines
    }

    private static func task(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = userMessage("Add Cmd+Shift+T to reopen the last closed tab, with tests.", on: canvas)
        lines += [
            .blank,
            DemoTerminalLine([DemoTerminalSpan(" ◇ ", DemoStyle.yellow), DemoTerminalSpan("Plan", DemoStyle.bold)]),
            planStep("Track closed tabs in TabStore", indent: "   "),
            planStep("Bind Cmd+Shift+T to reopen", indent: "   "),
            planStep("Cover reopen order with tests", indent: "   "),
            .blank,
            toolCall("Read", "Tabs/TabStore.swift", on: canvas),
            toolCall("Read", "Input/KeyboardShortcuts.swift", on: canvas),
            toolCall("Edit", "Tabs/TabStore.swift", additions: 17, deletions: 2, on: canvas),
            diffPreview(" 8", "-", "    private var lastClosed: Tab?", isFirst: true),
            diffPreview(" 8", "+", "    private var closedTabs: [ClosedTab] = []"),
            diffPreview(" 9", "+", "    private let closedTabLimit = 10"),
            toolCall("Edit", "Input/KeyboardShortcuts.swift", additions: 3, on: canvas),
            toolCall("Write", "Tests/TabStoreTests.swift", additions: 37, on: canvas),
            toolCall("Run", "swift test --filter TabStore", on: canvas),
            toolResult("✓ 18 tests passed", detail: " in 1.2s"),
            .blank
        ]
        return lines
    }

    private static func summary(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        var lines = paragraph("Cmd+Shift+T now reopens the most recently closed tab in its original position. TabStore keeps the last 10 closed tabs, and TabStoreTests covers ordering and the empty stack.", on: canvas)
        lines += [
            .blank,
            DemoTerminalLine([
                DemoTerminalSpan(" ✓ ", DemoStyle.green),
                DemoTerminalSpan("Done in 1m 12s · 3 files changed", DemoStyle.dim)
            ]),
            .blank
        ]
        return lines
    }

    private static func input(on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        let innerWidth = max(canvas.cols - 4, 0)
        let padding = max(innerWidth - prompt.count - 3, 0)
        return [
            DemoTerminalLine(" ╭" + String(repeating: "─", count: innerWidth) + "╮", DemoStyle.dim),
            DemoTerminalLine([
                DemoTerminalSpan(" │", DemoStyle.dim),
                DemoTerminalSpan(" › ", DemoStyle.combined(DemoStyle.bold, DemoStyle.magenta)),
                DemoTerminalSpan(prompt, DemoStyle.brightWhite),
                DemoTerminalSpan(String(repeating: " ", count: padding)),
                DemoTerminalSpan("│", DemoStyle.dim)
            ]),
            DemoTerminalLine(" ╰" + String(repeating: "─", count: innerWidth) + "╯", DemoStyle.dim),
            canvas.justified(
                [DemoTerminalSpan("   ▸ ", DemoStyle.magenta), DemoTerminalSpan("auto-edit on", DemoStyle.dim)],
                [DemoTerminalSpan("ctx 38%", DemoStyle.dim)]
            )
        ]
    }

    private static func sidebar() -> [DemoTerminalLine] {
        let session = box("Session", [
            [label("project"), DemoTerminalSpan("muxy")],
            [label("branch"), DemoTerminalSpan("feature/reopen-tab", DemoStyle.magenta)],
            [label("context"), DemoTerminalSpan("38%")]
        ])
        let plan = box("Plan", [
            planStep("Track closed tabs in TabStore", indent: "").spans,
            planStep("Bind Cmd+Shift+T to reopen", indent: "").spans,
            planStep("Cover reopen order with tests", indent: "").spans
        ])
        let changes = box("Changes", [
            change("M", "TabStore.swift", additions: 17, deletions: 2),
            change("M", "KeyboardShortcuts.swift", additions: 3),
            change("A", "TabStoreTests.swift", additions: 37)
        ])
        let tests = box("Tests", [
            [
                DemoTerminalSpan("✓ 18 passed", DemoStyle.green),
                DemoTerminalSpan("  ·  0 failed  ·  1.2s", DemoStyle.dim)
            ]
        ])
        return session + [.blank] + plan + [.blank] + changes + [.blank] + tests
    }

    private static func box(_ title: String, _ rows: [[DemoTerminalSpan]]) -> [DemoTerminalLine] {
        let contentWidth = sidebarWidth - 4
        let top = DemoTerminalLine([
            DemoTerminalSpan("╭─ ", DemoStyle.dim),
            DemoTerminalSpan(title, DemoStyle.bold),
            DemoTerminalSpan(" " + String(repeating: "─", count: max(sidebarWidth - title.count - 5, 0)) + "╮", DemoStyle.dim)
        ])
        let content = rows.map { spans in
            DemoTerminalLine([DemoTerminalSpan("│ ", DemoStyle.dim)])
                .appending(DemoTerminalLine(spans).padded(to: contentWidth).spans)
                .appending([DemoTerminalSpan(" │", DemoStyle.dim)])
        }
        let bottom = DemoTerminalLine("╰" + String(repeating: "─", count: sidebarWidth - 2) + "╯", DemoStyle.dim)
        return [top] + content + [bottom]
    }

    private static func label(_ text: String) -> DemoTerminalSpan {
        DemoTerminalSpan(text.padding(toLength: 9, withPad: " ", startingAt: 0), DemoStyle.dim)
    }

    private static func change(_ status: String, _ file: String, additions: Int, deletions: Int? = nil) -> [DemoTerminalSpan] {
        let stats = "+\(additions)" + (deletions.map { " −\($0)" } ?? "")
        let gap = max(sidebarWidth - 4 - status.count - 1 - file.count - stats.count, 1)
        var spans = [
            DemoTerminalSpan(status, status == "A" ? DemoStyle.green : DemoStyle.yellow),
            DemoTerminalSpan(" \(file)"),
            DemoTerminalSpan(String(repeating: " ", count: gap)),
            DemoTerminalSpan("+\(additions)", DemoStyle.green)
        ]
        if let deletions { spans.append(DemoTerminalSpan(" −\(deletions)", DemoStyle.red)) }
        return spans
    }

    private static func planStep(_ text: String, indent: String) -> DemoTerminalLine {
        DemoTerminalLine([DemoTerminalSpan("\(indent)✓ ", DemoStyle.green), DemoTerminalSpan(text, DemoStyle.dim)])
    }

    private static func toolResult(_ text: String, detail: String) -> DemoTerminalLine {
        DemoTerminalLine([
            DemoTerminalSpan("   └ ", DemoStyle.dim),
            DemoTerminalSpan(text, DemoStyle.green),
            DemoTerminalSpan(detail, DemoStyle.dim)
        ])
    }

    private static func diffPreview(_ line: String, _ marker: String, _ code: String, isFirst: Bool = false) -> DemoTerminalLine {
        let style = marker == "+" ? DemoStyle.green : DemoStyle.red
        return DemoTerminalLine([
            DemoTerminalSpan(isFirst ? "   └ " : "     ", DemoStyle.dim),
            DemoTerminalSpan("\(line) ", DemoStyle.dim),
            DemoTerminalSpan("\(marker)\(code)", style)
        ])
    }

    private static func userMessage(_ text: String, on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        DemoTerminalCanvas.wrap(text, width: canvas.cols - 4).map { line in
            DemoTerminalLine([
                DemoTerminalSpan(" ▌ ", DemoStyle.magenta),
                DemoTerminalSpan(line, DemoStyle.combined(DemoStyle.bold, DemoStyle.brightWhite))
            ])
        }
    }

    private static func paragraph(_ text: String, on canvas: DemoTerminalCanvas) -> [DemoTerminalLine] {
        DemoTerminalCanvas.wrap(text, width: canvas.cols - 2).map { DemoTerminalLine(" \($0)") }
    }

    private static func toolCall(
        _ verb: String,
        _ target: String,
        detail: String? = nil,
        additions: Int? = nil,
        deletions: Int? = nil,
        on canvas: DemoTerminalCanvas
    ) -> DemoTerminalLine {
        let left = [
            DemoTerminalSpan(" ● ", DemoStyle.green),
            DemoTerminalSpan(verb.padding(toLength: 7, withPad: " ", startingAt: 0), DemoStyle.bold),
            DemoTerminalSpan(target, DemoStyle.cyan)
        ]
        let right = [
            detail.map { DemoTerminalSpan($0, DemoStyle.dim) },
            additions.map { DemoTerminalSpan("+\($0)", DemoStyle.green) },
            deletions.map { DemoTerminalSpan(" −\($0)", DemoStyle.red) }
        ].compactMap { $0 }
        return canvas.justified(left, right)
    }
}
