import Foundation

nonisolated struct DemoFile: Sendable {
    let path: String
    let isDirectory: Bool
    let data: Data
    let isIgnored: Bool

    static func text(_ path: String, _ contents: String, isIgnored: Bool = false) -> DemoFile {
        DemoFile(path: path, isDirectory: false, data: Data(contents.utf8), isIgnored: isIgnored)
    }

    static func binary(_ path: String, _ data: Data) -> DemoFile {
        DemoFile(path: path, isDirectory: false, data: data, isIgnored: false)
    }

    static func directory(_ path: String, isIgnored: Bool = false) -> DemoFile {
        DemoFile(path: path, isDirectory: true, data: Data(), isIgnored: isIgnored)
    }
}

nonisolated struct DemoTabSeed: Sendable {
    let tab: Tab
    let screen: DemoTerminalScreen
}

nonisolated struct DemoProjectSeed: Sendable {
    let project: Project
    let worktreeID: UUID
    let areaID: UUID
    let tabs: [DemoTabSeed]
    let git: DemoGitState
    let files: [DemoFile]
}

nonisolated enum DemoCatalog {
    static let createdAt = "2026-06-08T00:00:00.000Z"
    static let projectsRoot = "/Users/demo/Projects"

    private static let workWorkspace = (id: id(701), name: "Work")
    private static let personalWorkspace = (id: id(702), name: "Personal")

    private struct Entry {
        let name: String
        let folder: String
        let icon: String
        let color: String
        let workspace: (id: UUID, name: String)
        let tabs: [(title: String, screen: DemoTerminalScreen)]
        let git: DemoGitState
    }

    static let projects: [DemoProjectSeed] = entries.enumerated().map { index, entry in
        seed(entry, index: index)
    }

    private static var entries: [Entry] {
        [
            Entry(
                name: "Muxy", folder: "muxy", icon: "terminal", color: "#c084fc", workspace: workWorkspace,
                tabs: [("agent", .agent), ("nvim", .editor), ("zsh", .shell)],
                git: muxyGit
            ),
            Entry(
                name: "Web App", folder: "web-app", icon: "globe", color: "#3b82f6", workspace: workWorkspace,
                tabs: [("dev", .devServer), ("zsh", .shell)],
                git: DemoGitState(otherBranches: ["feature/settings-page"])
            ),
            Entry(
                name: "API Server", folder: "api-server", icon: "server.rack", color: "#f97316", workspace: workWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Mobile App", folder: "mobile-app", icon: "app", color: "#ec4899", workspace: workWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Design System", folder: "design-system", icon: "paintpalette.fill", color: "#eab308", workspace: workWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Docs", folder: "docs", icon: "book", color: "#14b8a6", workspace: workWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Dotfiles", folder: "dotfiles", icon: "gearshape", color: "#94a3b8", workspace: personalWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Blog", folder: "blog", icon: "pencil", color: "#22c55e", workspace: personalWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            ),
            Entry(
                name: "Homelab", folder: "homelab", icon: "house", color: "#f43f5e", workspace: personalWorkspace,
                tabs: [("zsh", .shell)], git: DemoGitState()
            )
        ]
    }

    private static func seed(_ entry: Entry, index: Int) -> DemoProjectSeed {
        let number = index + 1
        let path = "\(projectsRoot)/\(entry.folder)"
        let project = Project(
            id: id(200 + number),
            name: entry.name,
            path: path,
            sortOrder: Double(index),
            createdAt: createdAt,
            icon: entry.icon,
            logo: nil,
            iconColor: entry.color,
            preferredWorktreeParentPath: projectsRoot,
            worktreesEnabled: false,
            workspaceKind: "local",
            workspaceID: entry.workspace.id,
            workspaceName: entry.workspace.name
        )
        let tabs = entry.tabs.enumerated().map { tabIndex, tab in
            DemoTabSeed(
                tab: Tab(
                    id: id(5000 + number * 10 + tabIndex),
                    kind: .terminal,
                    title: tab.title,
                    isPinned: false,
                    paneID: id(6000 + number * 10 + tabIndex)
                ),
                screen: tab.screen
            )
        }
        return DemoProjectSeed(
            project: project,
            worktreeID: id(300 + number),
            areaID: id(400 + number),
            tabs: tabs,
            git: entry.git,
            files: entry.folder == "muxy" ? muxyFiles : standardFiles(projectName: entry.name)
        )
    }

    private static var muxyGit: DemoGitState {
        let branch = "feature/reopen-tab"
        return DemoGitState(
            branch: branch,
            otherBranches: ["fix/split-pane-focus", "release/1.4"],
            aheadCount: 3,
            stagedFiles: [
                VCSFile(path: DemoSources.tabStorePath, status: .modified, isUntracked: false),
                VCSFile(path: DemoSources.keyboardShortcutsPath, status: .modified, isUntracked: false),
                VCSFile(path: DemoSources.tabStoreTestsPath, status: .added, isUntracked: false)
            ],
            changedFiles: [
                VCSFile(path: DemoSources.changelogPath, status: .modified, isUntracked: false)
            ],
            pullRequests: [
                branch: VCSPullRequest(
                    url: "https://github.com/muxy-app/demo/pull/128",
                    number: 128,
                    state: "OPEN",
                    isDraft: false,
                    baseBranch: DemoGitState.defaultBranch,
                    mergeable: true,
                    mergeStateStatus: .clean,
                    checks: VCSPRChecks(status: .success, passing: 4, failing: 0, pending: 0, total: 4),
                    headOid: nil
                )
            ],
            diffs: [
                DemoSources.tabStorePath: DemoSources.tabStoreDiff,
                DemoSources.keyboardShortcutsPath: DemoSources.keyboardShortcutsDiff,
                DemoSources.tabStoreTestsPath: DemoDiffParser.addedFile(DemoSources.tabStoreTests),
                DemoSources.changelogPath: DemoSources.changelogDiff
            ]
        )
    }

    private static var muxyFiles: [DemoFile] {
        [
            .directory(".build", isIgnored: true),
            .text(".build/debug.yaml", "client:\n  name: basic\n", isIgnored: true),
            .text(".github/workflows/ci.yml", DemoSources.continuousIntegration),
            .text("Sources/Muxy/MuxyApp.swift", DemoSources.app),
            .text(DemoSources.tabStorePath, DemoSources.tabStore),
            .text(DemoSources.keyboardShortcutsPath, DemoSources.keyboardShortcuts),
            .text(DemoSources.tabStoreTestsPath, DemoSources.tabStoreTests),
            .binary("assets/icon.png", iconData),
            .text(DemoSources.changelogPath, DemoSources.changelog),
            .text("LICENSE", DemoSources.license),
            .text("Package.swift", DemoSources.package),
            .text("README.md", DemoSources.readme)
        ]
    }

    private static func standardFiles(projectName: String) -> [DemoFile] {
        [
            .text("Sources/App.swift", "import SwiftUI\n\nstruct HomeView: View {\n    var body: some View {\n        Text(\"Welcome to \(projectName)\")\n    }\n}\n"),
            .text("TerminalKeyboardVisibilityConfiguration.swift", """
            import Foundation

            struct TerminalKeyboardVisibilityConfiguration {
                let preservesTerminalGrid: Bool
                let followsCursorWhenKeyboardOpens: Bool
                let allowsManualViewportScrolling: Bool
            }

            let configuration = TerminalKeyboardVisibilityConfiguration(preservesTerminalGrid: true, followsCursorWhenKeyboardOpens: true, allowsManualViewportScrolling: true)

            """),
            .binary("assets/icon.png", iconData),
            .text("README.md", DemoSources.readme.replacingOccurrences(of: "# Muxy", with: "# \(projectName)")),
            .directory(".build", isIgnored: true),
            .text(".build/state.json", "{}\n", isIgnored: true),
            .binary("archive.bin", Data([0xFF, 0xFE, 0x00, 0x01]))
        ]
    }

    private static let iconData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=") ?? Data()

    private static func id(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", value))!
    }
}
