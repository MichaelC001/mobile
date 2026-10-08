package com.muxy.app.features.demo

internal object DemoAgentScreen {
    private const val PROMPT = "Open a pull request"
    private const val SIDEBAR_WIDTH = 38
    private const val SIDEBAR_GAP = 2
    private const val VERB_WIDTH = 7
    private const val LABEL_WIDTH = 9

    fun render(canvas: DemoTerminalCanvas): String {
        if (!canvas.isWide) return canvas.render(transcript(canvas), input(canvas), cursor(canvas))
        val conversation = DemoTerminalCanvas(canvas.cols - SIDEBAR_WIDTH - SIDEBAR_GAP, canvas.rows)
        val left = conversation.compose(transcript(conversation), input(conversation))
        val lines = DemoTerminalCanvas.columns(left, conversation.cols, DemoTerminalSpan(" ".repeat(SIDEBAR_GAP)), sidebar())
        return canvas.render(lines, cursor(conversation))
    }

    private fun cursor(canvas: DemoTerminalCanvas) = DemoTerminalCursor(maxOf(canvas.rows - 2, 1), minOf(PROMPT.length + 6, canvas.cols))

    private fun transcript(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        header() + history(canvas) + rebase(canvas) + testRun(canvas) + question(canvas) + task(canvas) + summary(canvas)

    private fun header(): List<DemoTerminalLine> =
        listOf(
            DemoTerminalLine(
                listOf(
                    DemoTerminalSpan(" ◆ agent", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.MAGENTA)),
                    DemoTerminalSpan("  ~/Projects/muxy", DemoStyle.DIM),
                ),
            ),
            DemoTerminalLine.BLANK,
        )

    private fun history(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        userMessage("What landed on main since yesterday?", canvas) +
            listOf(
                DemoTerminalLine.BLANK,
                toolCall("Run", "git log --oneline origin/main@{1.day.ago}..", canvas),
                toolResult("✓ 5 commits", ""),
                commit("a41f2c9", "Fix split pane focus after closing a tab"),
                commit("9be03d1", "Add worktree picker to the command palette"),
                commit("77c5e10", "Speed up project list loading"),
                commit("3d0b8aa", "Keep scrollback when a pane is resized"),
                commit("e52f4c7", "Show branch ahead and behind counts"),
                DemoTerminalLine.BLANK,
            ) +
            paragraph("Mostly worktree and split pane fixes. Nothing touches TabStore yet.", canvas) +
            DemoTerminalLine.BLANK

    private fun commit(
        hash: String,
        message: String,
    ) = DemoTerminalLine(listOf(DemoTerminalSpan("     $hash ", DemoStyle.YELLOW), DemoTerminalSpan(message, DemoStyle.DIM)))

    private fun rebase(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        userMessage("Pull the latest main and rebase my branch", canvas) +
            listOf(
                DemoTerminalLine.BLANK,
                toolCall("Run", "git pull --rebase origin main", canvas),
                toolResult("✓ Rebased 3 commits onto main", ""),
                DemoTerminalLine.BLANK,
            ) +
            paragraph("Your branch is up to date with origin/main and 3 commits ahead.", canvas) +
            DemoTerminalLine.BLANK

    private fun testRun(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        userMessage("Run the full test suite", canvas) +
            listOf(
                DemoTerminalLine.BLANK,
                toolCall("Run", "swift test", canvas),
                toolResult("✓ 214 tests passed", " in 8.4s"),
                DemoTerminalLine.BLANK,
            ) +
            paragraph("All green. The slowest suite is WorktreeTests at 2.1s.", canvas) +
            DemoTerminalLine.BLANK

    private fun question(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        userMessage("How are tabs closed today?", canvas) +
            listOf(DemoTerminalLine.BLANK, toolCall("Search", "\"closeTab\"", canvas, detail = "6 matches"), DemoTerminalLine.BLANK) +
            paragraph(
                "TabStore.close(_:) removes the tab and focuses its neighbour. Closed tabs are discarded, so there is no way to bring one back.",
                canvas,
            ) +
            DemoTerminalLine.BLANK

    private fun task(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        userMessage("Add Cmd+Shift+T to reopen the last closed tab, with tests.", canvas) +
            listOf(
                DemoTerminalLine.BLANK,
                DemoTerminalLine(listOf(DemoTerminalSpan(" ◇ ", DemoStyle.YELLOW), DemoTerminalSpan("Plan", DemoStyle.BOLD))),
                planStep("Track closed tabs in TabStore", "   "),
                planStep("Bind Cmd+Shift+T to reopen", "   "),
                planStep("Cover reopen order with tests", "   "),
                DemoTerminalLine.BLANK,
                toolCall("Read", "Tabs/TabStore.swift", canvas),
                toolCall("Read", "Input/KeyboardShortcuts.swift", canvas),
                toolCall("Edit", "Tabs/TabStore.swift", canvas, additions = 17, deletions = 2),
                diffPreview(" 8", "-", "    private var lastClosed: Tab?", isFirst = true),
                diffPreview(" 8", "+", "    private var closedTabs: [ClosedTab] = []"),
                diffPreview(" 9", "+", "    private let closedTabLimit = 10"),
                toolCall("Edit", "Input/KeyboardShortcuts.swift", canvas, additions = 3),
                toolCall("Write", "Tests/TabStoreTests.swift", canvas, additions = 37),
                toolCall("Run", "swift test --filter TabStore", canvas),
                toolResult("✓ 18 tests passed", " in 1.2s"),
                DemoTerminalLine.BLANK,
            )

    private fun summary(canvas: DemoTerminalCanvas): List<DemoTerminalLine> =
        paragraph(
            "Cmd+Shift+T now reopens the most recently closed tab in its original position. " +
                "TabStore keeps the last 10 closed tabs, and TabStoreTests covers ordering and the empty stack.",
            canvas,
        ) +
            listOf(
                DemoTerminalLine.BLANK,
                DemoTerminalLine(
                    listOf(
                        DemoTerminalSpan(" ✓ ", DemoStyle.GREEN),
                        DemoTerminalSpan("Done in 1m 12s · 3 files changed", DemoStyle.DIM),
                    ),
                ),
                DemoTerminalLine.BLANK,
            )

    private fun input(canvas: DemoTerminalCanvas): List<DemoTerminalLine> {
        val innerWidth = maxOf(canvas.cols - 4, 0)
        val padding = maxOf(innerWidth - PROMPT.length - 3, 0)
        return listOf(
            DemoTerminalLine(" ╭" + "─".repeat(innerWidth) + "╮", DemoStyle.DIM),
            DemoTerminalLine(
                listOf(
                    DemoTerminalSpan(" │", DemoStyle.DIM),
                    DemoTerminalSpan(" › ", DemoStyle.combined(DemoStyle.BOLD, DemoStyle.MAGENTA)),
                    DemoTerminalSpan(PROMPT, DemoStyle.BRIGHT_WHITE),
                    DemoTerminalSpan(" ".repeat(padding)),
                    DemoTerminalSpan("│", DemoStyle.DIM),
                ),
            ),
            DemoTerminalLine(" ╰" + "─".repeat(innerWidth) + "╯", DemoStyle.DIM),
            canvas.justified(
                listOf(DemoTerminalSpan("   ▸ ", DemoStyle.MAGENTA), DemoTerminalSpan("auto-edit on", DemoStyle.DIM)),
                listOf(DemoTerminalSpan("ctx 38%", DemoStyle.DIM)),
            ),
        )
    }

    private fun sidebar(): List<DemoTerminalLine> {
        val session =
            box(
                "Session",
                listOf(
                    listOf(label("project"), DemoTerminalSpan("muxy")),
                    listOf(label("branch"), DemoTerminalSpan("feature/reopen-tab", DemoStyle.MAGENTA)),
                    listOf(label("context"), DemoTerminalSpan("38%")),
                ),
            )
        val plan =
            box(
                "Plan",
                listOf(
                    planStep("Track closed tabs in TabStore", "").spans,
                    planStep("Bind Cmd+Shift+T to reopen", "").spans,
                    planStep("Cover reopen order with tests", "").spans,
                ),
            )
        val changes =
            box(
                "Changes",
                listOf(
                    change("M", "TabStore.swift", 17, 2),
                    change("M", "KeyboardShortcuts.swift", 3),
                    change("A", "TabStoreTests.swift", 37),
                ),
            )
        val tests =
            box(
                "Tests",
                listOf(listOf(DemoTerminalSpan("✓ 18 passed", DemoStyle.GREEN), DemoTerminalSpan("  ·  0 failed  ·  1.2s", DemoStyle.DIM))),
            )
        return session + DemoTerminalLine.BLANK + plan + DemoTerminalLine.BLANK + changes + DemoTerminalLine.BLANK + tests
    }

    private fun box(
        title: String,
        rows: List<List<DemoTerminalSpan>>,
    ): List<DemoTerminalLine> {
        val top =
            DemoTerminalLine(
                listOf(
                    DemoTerminalSpan("╭─ ", DemoStyle.DIM),
                    DemoTerminalSpan(title, DemoStyle.BOLD),
                    DemoTerminalSpan(" " + "─".repeat(maxOf(SIDEBAR_WIDTH - title.length - 5, 0)) + "╮", DemoStyle.DIM),
                ),
            )
        val content =
            rows.map { spans ->
                DemoTerminalLine(listOf(DemoTerminalSpan("│ ", DemoStyle.DIM)))
                    .appending(DemoTerminalLine(spans).padded(SIDEBAR_WIDTH - 4).spans)
                    .appending(listOf(DemoTerminalSpan(" │", DemoStyle.DIM)))
            }
        val bottom = DemoTerminalLine("╰" + "─".repeat(SIDEBAR_WIDTH - 2) + "╯", DemoStyle.DIM)
        return listOf(top) + content + bottom
    }

    private fun label(text: String) = DemoTerminalSpan(text.padEnd(LABEL_WIDTH), DemoStyle.DIM)

    private fun change(
        status: String,
        file: String,
        additions: Int,
        deletions: Int? = null,
    ): List<DemoTerminalSpan> {
        val stats = "+$additions" + (deletions?.let { " −$it" } ?: "")
        val gap = maxOf(SIDEBAR_WIDTH - 4 - status.length - 1 - file.length - stats.length, 1)
        val deletionSpan = deletions?.let { listOf(DemoTerminalSpan(" −$it", DemoStyle.RED)) } ?: emptyList()
        return listOf(
            DemoTerminalSpan(status, if (status == "A") DemoStyle.GREEN else DemoStyle.YELLOW),
            DemoTerminalSpan(" $file"),
            DemoTerminalSpan(" ".repeat(gap)),
            DemoTerminalSpan("+$additions", DemoStyle.GREEN),
        ) + deletionSpan
    }

    private fun planStep(
        text: String,
        indent: String,
    ) = DemoTerminalLine(listOf(DemoTerminalSpan("$indent✓ ", DemoStyle.GREEN), DemoTerminalSpan(text, DemoStyle.DIM)))

    private fun toolResult(
        text: String,
        detail: String,
    ) = DemoTerminalLine(
        listOf(
            DemoTerminalSpan("   └ ", DemoStyle.DIM),
            DemoTerminalSpan(text, DemoStyle.GREEN),
            DemoTerminalSpan(detail, DemoStyle.DIM),
        ),
    )

    private fun diffPreview(
        line: String,
        marker: String,
        code: String,
        isFirst: Boolean = false,
    ) = DemoTerminalLine(
        listOf(
            DemoTerminalSpan(if (isFirst) "   └ " else "     ", DemoStyle.DIM),
            DemoTerminalSpan("$line ", DemoStyle.DIM),
            DemoTerminalSpan("$marker$code", if (marker == "+") DemoStyle.GREEN else DemoStyle.RED),
        ),
    )

    private fun userMessage(
        text: String,
        canvas: DemoTerminalCanvas,
    ): List<DemoTerminalLine> =
        DemoTerminalCanvas.wrap(text, canvas.cols - 4).map { line ->
            DemoTerminalLine(
                listOf(
                    DemoTerminalSpan(" ▌ ", DemoStyle.MAGENTA),
                    DemoTerminalSpan(line, DemoStyle.combined(DemoStyle.BOLD, DemoStyle.BRIGHT_WHITE)),
                ),
            )
        }

    private fun paragraph(
        text: String,
        canvas: DemoTerminalCanvas,
    ): List<DemoTerminalLine> = DemoTerminalCanvas.wrap(text, canvas.cols - 2).map { DemoTerminalLine(" $it") }

    private fun toolCall(
        verb: String,
        target: String,
        canvas: DemoTerminalCanvas,
        detail: String? = null,
        additions: Int? = null,
        deletions: Int? = null,
    ): DemoTerminalLine {
        val left =
            listOf(
                DemoTerminalSpan(" ● ", DemoStyle.GREEN),
                DemoTerminalSpan(verb.padEnd(VERB_WIDTH), DemoStyle.BOLD),
                DemoTerminalSpan(target, DemoStyle.CYAN),
            )
        val right =
            listOfNotNull(
                detail?.let { DemoTerminalSpan(it, DemoStyle.DIM) },
                additions?.let { DemoTerminalSpan("+$it", DemoStyle.GREEN) },
                deletions?.let { DemoTerminalSpan(" −$it", DemoStyle.RED) },
            )
        return canvas.justified(left, right)
    }
}
