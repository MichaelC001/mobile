package com.muxy.app.features.demo

import com.muxy.app.models.Project
import com.muxy.app.models.Tab
import com.muxy.app.models.TabKind
import com.muxy.app.models.VcsChecks
import com.muxy.app.models.VcsChecksStatus
import com.muxy.app.models.VcsFile
import com.muxy.app.models.VcsFileStatus
import com.muxy.app.models.VcsPullRequest
import java.util.Base64
import java.util.UUID

internal class DemoFile private constructor(
    val path: String,
    val isDirectory: Boolean,
    val data: ByteArray,
    val isIgnored: Boolean,
) {
    companion object {
        fun text(
            path: String,
            contents: String,
            isIgnored: Boolean = false,
        ) = DemoFile(path, false, contents.toByteArray(), isIgnored)

        fun binary(
            path: String,
            data: ByteArray,
        ) = DemoFile(path, false, data, false)

        fun directory(
            path: String,
            isIgnored: Boolean = false,
        ) = DemoFile(path, true, byteArrayOf(), isIgnored)
    }
}

internal data class DemoTabSeed(
    val tab: Tab,
    val screen: DemoTerminalScreen,
)

internal class DemoProjectSeed(
    val project: Project,
    val worktreeId: UUID,
    val areaId: UUID,
    val tabs: List<DemoTabSeed>,
    val git: DemoGitSeed,
    val files: List<DemoFile>,
)

internal object DemoCatalog {
    const val CREATED_AT = "2026-06-08T00:00:00.000Z"
    private const val PROJECTS_ROOT = "/Users/demo/Projects"
    private const val MUXY_FOLDER = "muxy"
    private const val ICON = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    private data class Workspace(
        val id: UUID,
        val name: String,
    )

    private data class Entry(
        val name: String,
        val folder: String,
        val icon: String,
        val color: String,
        val workspace: Workspace,
        val tabs: List<Pair<String, DemoTerminalScreen>>,
        val git: DemoGitSeed = DemoGitSeed(),
    )

    private val work = Workspace(id(701), "Work")
    private val personal = Workspace(id(702), "Personal")
    private val shellOnly = listOf("zsh" to DemoTerminalScreen.SHELL)

    val projects: List<DemoProjectSeed> by lazy { entries().mapIndexed(::seed) }

    private fun entries() =
        listOf(
            Entry(
                "Muxy",
                MUXY_FOLDER,
                "terminal",
                "#c084fc",
                work,
                listOf("agent" to DemoTerminalScreen.AGENT, "nvim" to DemoTerminalScreen.EDITOR, "zsh" to DemoTerminalScreen.SHELL),
                muxyGit(),
            ),
            Entry(
                "Web App",
                "web-app",
                "globe",
                "#3b82f6",
                work,
                listOf("dev" to DemoTerminalScreen.DEV_SERVER, "zsh" to DemoTerminalScreen.SHELL),
                DemoGitSeed(otherBranches = listOf("feature/settings-page")),
            ),
            Entry("API Server", "api-server", "server.rack", "#f97316", work, shellOnly),
            Entry("Mobile App", "mobile-app", "app", "#ec4899", work, shellOnly),
            Entry("Design System", "design-system", "paintpalette.fill", "#eab308", work, shellOnly),
            Entry("Docs", "docs", "book", "#14b8a6", work, shellOnly),
            Entry("Dotfiles", "dotfiles", "gearshape", "#94a3b8", personal, shellOnly),
            Entry("Blog", "blog", "pencil", "#22c55e", personal, shellOnly),
            Entry("Homelab", "homelab", "house", "#f43f5e", personal, shellOnly),
        )

    private fun seed(
        index: Int,
        entry: Entry,
    ): DemoProjectSeed {
        val number = index + 1
        val project =
            Project(
                id = id(200 + number),
                name = entry.name,
                path = "$PROJECTS_ROOT/${entry.folder}",
                sortOrder = index.toDouble(),
                createdAt = CREATED_AT,
                icon = entry.icon,
                iconColor = entry.color,
                preferredWorktreeParentPath = PROJECTS_ROOT,
                worktreesEnabled = false,
                workspaceKind = "local",
                workspaceId = entry.workspace.id,
                workspaceName = entry.workspace.name,
            )
        val tabs =
            entry.tabs.mapIndexed { tabIndex, (title, screen) ->
                val tab = Tab(id(5000 + number * 10 + tabIndex), TabKind.Terminal, title, false, id(6000 + number * 10 + tabIndex))
                DemoTabSeed(tab, screen)
            }
        val files = if (entry.folder == MUXY_FOLDER) muxyFiles() else standardFiles(entry.name)
        return DemoProjectSeed(project, id(300 + number), id(400 + number), tabs, entry.git, files)
    }

    private fun muxyGit(): DemoGitSeed {
        val branch = "feature/reopen-tab"
        return DemoGitSeed(
            branch = branch,
            otherBranches = listOf("fix/split-pane-focus", "release/1.4"),
            aheadCount = 3,
            stagedFiles =
                listOf(
                    VcsFile(DemoSources.TAB_STORE_PATH, VcsFileStatus.MODIFIED, false),
                    VcsFile(DemoSources.KEYBOARD_SHORTCUTS_PATH, VcsFileStatus.MODIFIED, false),
                    VcsFile(DemoSources.TAB_STORE_TESTS_PATH, VcsFileStatus.ADDED, false),
                ),
            changedFiles = listOf(VcsFile(DemoSources.CHANGELOG_PATH, VcsFileStatus.MODIFIED, false)),
            pullRequests =
                mapOf(
                    branch to
                        VcsPullRequest(
                            url = "https://github.com/muxy-app/demo/pull/128",
                            number = 128,
                            state = "OPEN",
                            isDraft = false,
                            baseBranch = DemoGitStore.DEFAULT_BRANCH,
                            mergeable = true,
                            mergeStateStatus = "CLEAN",
                            checks = VcsChecks(VcsChecksStatus.SUCCESS, 4, 0, 0, 4),
                        ),
                ),
            diffs =
                mapOf(
                    DemoSources.TAB_STORE_PATH to DemoSources.TAB_STORE_DIFF,
                    DemoSources.KEYBOARD_SHORTCUTS_PATH to DemoSources.KEYBOARD_SHORTCUTS_DIFF,
                    DemoSources.TAB_STORE_TESTS_PATH to DemoDiffParser.addedFile(DemoSources.TAB_STORE_TESTS),
                    DemoSources.CHANGELOG_PATH to DemoSources.CHANGELOG_DIFF,
                ),
        )
    }

    private fun muxyFiles() =
        listOf(
            DemoFile.directory(".build", isIgnored = true),
            DemoFile.text(".build/debug.yaml", "client:\n  name: basic\n", isIgnored = true),
            DemoFile.text(".github/workflows/ci.yml", DemoSources.CONTINUOUS_INTEGRATION),
            DemoFile.text("Sources/Muxy/MuxyApp.swift", DemoSources.APP),
            DemoFile.text(DemoSources.TAB_STORE_PATH, DemoSources.TAB_STORE),
            DemoFile.text(DemoSources.KEYBOARD_SHORTCUTS_PATH, DemoSources.KEYBOARD_SHORTCUTS),
            DemoFile.text(DemoSources.TAB_STORE_TESTS_PATH, DemoSources.TAB_STORE_TESTS),
            DemoFile.binary("assets/icon.png", iconData()),
            DemoFile.text(DemoSources.CHANGELOG_PATH, DemoSources.CHANGELOG),
            DemoFile.text("LICENSE", DemoSources.LICENSE),
            DemoFile.text("Package.swift", DemoSources.PACKAGE),
            DemoFile.text("README.md", DemoSources.readme("Muxy")),
        )

    private fun standardFiles(projectName: String) =
        listOf(
            DemoFile.text(
                "Sources/App.swift",
                "import SwiftUI\n\nstruct HomeView: View {\n    var body: some View {\n        Text(\"Welcome to $projectName\")\n    }\n}\n",
            ),
            DemoFile.text(
                "TerminalKeyboardVisibilityConfiguration.swift",
                """
                import Foundation

                struct TerminalKeyboardVisibilityConfiguration {
                    let preservesTerminalGrid: Bool
                    let followsCursorWhenKeyboardOpens: Bool
                    let allowsManualViewportScrolling: Bool
                }

                let configuration = TerminalKeyboardVisibilityConfiguration(preservesTerminalGrid: true, followsCursorWhenKeyboardOpens: true, allowsManualViewportScrolling: true)
                """.trimIndent(),
            ),
            DemoFile.text("README.md", DemoSources.readme(projectName)),
            DemoFile.binary("assets/icon.png", iconData()),
            DemoFile.binary("archive.bin", byteArrayOf(0xff.toByte(), 0xfe.toByte(), 0, 1)),
            DemoFile.directory(".build", isIgnored = true),
            DemoFile.text(".build/state.json", "{}\n", isIgnored = true),
        )

    private fun iconData(): ByteArray = Base64.getDecoder().decode(ICON)

    private fun id(value: Int): UUID = UUID.fromString("00000000-0000-4000-8000-" + value.toString().padStart(12, '0'))
}
