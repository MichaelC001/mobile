import Foundation

actor DemoBackend {
    private let clientID = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
    private let seeds = DemoCatalog.projects
    private var workspaces: [UUID: Workspace] = [:]
    private var gitStates: [UUID: DemoGitState] = [:]
    private var fileStores: [UUID: DemoFileStore] = [:]
    private var paneScreens: [UUID: DemoTerminalScreen] = [:]
    private var pendingFileEvents: [EventEnvelope] = []
    private var tabCounter = 2

    init() {
        for seed in seeds {
            let projectID = seed.project.id
            workspaces[projectID] = Self.makeWorkspace(seed)
            gitStates[projectID] = seed.git
            fileStores[projectID] = DemoFileStore(files: seed.files)
            for tab in seed.tabs {
                guard let paneID = tab.tab.paneID else { continue }
                paneScreens[paneID] = tab.screen
            }
        }
    }

    var currentClientID: UUID { clientID }

    func authenticate() throws -> RawTagged {
        try tagged(
            ResultType.pairing,
            PairingResult(
                clientID: clientID.uuidString,
                deviceName: DemoConnection.connection.name
            )
        )
    }

    func request<P: Codable & Sendable>(_ method: Method, params: P?) throws -> RawTagged {
        if DemoFileStore.handles(method) { return try handleFiles(method, params: params) }
        if let result = try handleProject(method, params: params) { return result }
        if let result = try handleTab(method, params: params) { return result }
        if let result = try handleTerminal(method) { return result }
        if let result = try handleVCS(method, params: params) { return result }
        throw DemoError.notFound
    }

    private func handleFiles<P: Codable & Sendable>(_ method: Method, params: P?) throws -> RawTagged {
        let context = try decode(VCSProjectParams.self, from: params)
        let projectID = try projectID(from: context.projectID)
        guard var store = fileStores[projectID] else { throw DemoError.notFound }
        let result = try store.request(method, params: params)
        fileStores[projectID] = store
        if !store.changedPaths.isEmpty {
            pendingFileEvents.append(try event(EventName.fileChanged, EventType.fileChanged, FileChangedEvent(
                projectID: projectID,
                worktreeID: workspaces[projectID]?.worktreeID,
                paths: store.changedPaths,
                truncated: false
            )))
        }
        return result
    }

    private func handleProject<P: Codable & Sendable>(_ method: Method, params: P?) throws -> RawTagged? {
        switch method {
        case .authenticateDevice:
            return try authenticate()
        case .listProjects:
            return try tagged(ResultType.projects, ProjectsResult(projects: projects))
        case .selectProject, .selectWorktree:
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .listWorktrees:
            let params = try decode(ListWorktreesParams.self, from: params)
            return try tagged(ResultType.worktrees, worktrees(for: projectID(from: params.projectID)))
        case .getWorkspace:
            let params = try decode(GetWorkspaceParams.self, from: params)
            let id = try projectID(from: params.projectID)
            guard let workspace = workspaces[id] else { throw DemoError.notFound }
            return try tagged(ResultType.workspace, workspace)
        default:
            return nil
        }
    }

    private func handleTab<P: Codable & Sendable>(_ method: Method, params: P?) throws -> RawTagged? {
        switch method {
        case .createTab:
            let params = try decode(CreateTabParams.self, from: params)
            let projectID = try projectID(from: params.projectID)
            let tab = try createTab(projectID: projectID, areaID: params.areaID)
            return try tagged(ResultType.tab, tab)
        case .closeTab:
            let params = try decode(CloseTabParams.self, from: params)
            try closeTab(projectID: projectID(from: params.projectID), areaID: areaID(from: params.areaID), tabID: tabID(from: params.tabID))
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .selectTab:
            let params = try decode(SelectTabParams.self, from: params)
            try selectTab(projectID: projectID(from: params.projectID), areaID: areaID(from: params.areaID), tabID: tabID(from: params.tabID))
            return try tagged(ResultType.ok, EmptyDemoResult())
        default:
            return nil
        }
    }

    private func handleTerminal(_ method: Method) throws -> RawTagged? {
        switch method {
        case .takeOverPane, .terminalResize, .terminalScroll, .setClientTheme, .releasePane, .terminalInput:
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .getProjectLogo:
            throw DemoError.notFound
        default:
            return nil
        }
    }

    private func handleVCS<P: Codable & Sendable>(_ method: Method, params: P?) throws -> RawTagged? {
        switch method {
        case .vcsRefresh:
            let params = try decode(VCSProjectParams.self, from: params)
            return try tagged(ResultType.vcsStatus, gitState(for: projectID(from: params.projectID)).status)
        case .vcsCommit:
            let params = try decode(VCSCommitParams.self, from: params)
            try updateGit(projectID(from: params.projectID)) { $0.commit() }
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .vcsPush, .vcsPull, .vcsMergePullRequest, .vcsRemoveWorktree:
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .vcsListBranches:
            let params = try decode(VCSProjectParams.self, from: params)
            return try tagged(ResultType.vcsBranches, gitState(for: projectID(from: params.projectID)).branchList)
        case .vcsSwitchBranch:
            let params = try decode(VCSBranchParams.self, from: params)
            try updateGit(projectID(from: params.projectID)) { $0.checkout(params.branch) }
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .vcsCreateBranch:
            let params = try decode(VCSCreateBranchParams.self, from: params)
            try updateGit(projectID(from: params.projectID)) { $0.checkout(params.name) }
            return try tagged(ResultType.ok, EmptyDemoResult())
        case .vcsCreatePR:
            return try tagged(ResultType.vcsPRCreated, VCSPRCreated(url: "https://github.com/muxy-app/demo/pull/42", number: 42))
        case .vcsAddWorktree:
            let params = try decode(VCSAddWorktreeParams.self, from: params)
            return try tagged(ResultType.worktrees, worktrees(for: projectID(from: params.projectID)))
        case .vcsGetDiff:
            let params = try decode(VCSGetDiffParams.self, from: params)
            let state = try gitState(for: projectID(from: params.projectID))
            return try tagged(ResultType.vcsDiff, state.diff(for: params.filePath, truncated: !params.forceFull))
        default:
            return nil
        }
    }

    func events<P: Codable & Sendable>(for method: Method, params: P?) throws -> [EventEnvelope] {
        if DemoFileStore.handles(method) {
            let events = pendingFileEvents
            pendingFileEvents = []
            return events
        }
        switch method {
        case .createTab:
            let params = try decode(CreateTabParams.self, from: params)
            return try workspaceEvents(projectID: projectID(from: params.projectID))
        case .closeTab:
            let params = try decode(CloseTabParams.self, from: params)
            return try workspaceEvents(projectID: projectID(from: params.projectID))
        case .selectTab:
            let params = try decode(SelectTabParams.self, from: params)
            return try workspaceEvents(projectID: projectID(from: params.projectID))
        case .takeOverPane:
            let params = try decode(TakeOverPaneParams.self, from: params)
            let paneID = try paneID(from: params.paneID)
            return [
                try event(EventName.paneOwnershipChanged, EventType.paneOwnership, PaneOwnershipEvent(
                    paneID: paneID,
                    owner: .remote(deviceID: clientID, deviceName: "iPhone (Demo)")
                )),
                try snapshotEvent(paneID: paneID, cols: params.cols, rows: params.rows)
            ]
        case .terminalResize:
            let params = try decode(TerminalResizeParams.self, from: params)
            let paneID = try paneID(from: params.paneID)
            guard screen(for: paneID).redrawsOnResize else { return [] }
            return [try snapshotEvent(paneID: paneID, cols: params.cols, rows: params.rows)]
        case .terminalInput:
            let params = try decode(TerminalInputParams.self, from: params)
            let text = String(data: params.bytes, encoding: .utf8) ?? ""
            let output = response(for: text)
            return [
                try event(EventName.terminalOutput, EventType.terminalOutput, TerminalBytesEvent(
                    paneID: try paneID(from: params.paneID),
                    bytes: Data(output.utf8)
                ))
            ]
        default:
            return []
        }
    }

    private func gitState(for projectID: UUID) throws -> DemoGitState {
        guard let state = gitStates[projectID] else { throw DemoError.notFound }
        return state
    }

    private func updateGit(_ projectID: UUID, _ change: (inout DemoGitState) -> Void) throws {
        var state = try gitState(for: projectID)
        change(&state)
        gitStates[projectID] = state
    }

    private func worktrees(for projectID: UUID) throws -> [Worktree] {
        guard let seed = seeds.first(where: { $0.project.id == projectID }) else { throw DemoError.notFound }
        return [
            Worktree(
                id: seed.worktreeID,
                name: seed.project.name,
                path: seed.project.path,
                branch: try gitState(for: projectID).branch,
                isPrimary: true,
                canBeRemoved: false,
                createdAt: DemoCatalog.createdAt
            )
        ]
    }

    private var projects: [Project] {
        seeds.map(\.project)
    }

    private func screen(for paneID: UUID) -> DemoTerminalScreen {
        paneScreens[paneID] ?? .shell
    }

    private func snapshotEvent(paneID: UUID, cols: Int, rows: Int) throws -> EventEnvelope {
        try event(EventName.terminalSnapshot, EventType.terminalSnapshot, TerminalBytesEvent(
            paneID: paneID,
            bytes: Data(screen(for: paneID).render(cols: cols, rows: rows).utf8)
        ))
    }

    private func response(for text: String) -> String {
        guard text.contains("\r") || text.contains("\n") else { return text }
        let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = command.isEmpty ? "" : "\r\n\u{001B}[33m[Demo Mode]\u{001B}[0m Commands are not executed in demo mode.\r\n"
        return "\(text)\(body)demo@muxy ~ % "
    }

    private func workspaceEvents(projectID: UUID) throws -> [EventEnvelope] {
        guard let workspace = workspaces[projectID] else { throw DemoError.notFound }
        return [try event(EventName.workspaceChanged, EventType.workspace, workspace)]
    }

    private func createTab(projectID: UUID, areaID: String?) throws -> Tab {
        guard let workspace = workspaces[projectID], case let .tabArea(area) = workspace.root else { throw DemoError.notFound }
        if let areaID, area.id != UUID(uuidString: areaID) { throw DemoError.notFound }
        tabCounter += 1
        let tab = Tab(
            id: UUID(),
            kind: .terminal,
            title: "zsh \(tabCounter)",
            isPinned: false,
            paneID: UUID()
        )
        let updatedArea = TabArea(
            id: area.id,
            projectPath: area.projectPath,
            tabs: area.tabs + [tab],
            activeTabID: tab.id
        )
        workspaces[projectID] = Workspace(
            projectID: workspace.projectID,
            worktreeID: workspace.worktreeID,
            focusedAreaID: updatedArea.id,
            root: .tabArea(updatedArea)
        )
        return tab
    }

    private func closeTab(projectID: UUID, areaID: UUID, tabID: UUID) throws {
        guard let workspace = workspaces[projectID], case let .tabArea(area) = workspace.root, area.id == areaID else { throw DemoError.notFound }
        let tabs = area.tabs.filter { $0.id != tabID }
        let updatedArea = TabArea(
            id: area.id,
            projectPath: area.projectPath,
            tabs: tabs,
            activeTabID: area.activeTabID == tabID ? tabs.first?.id : area.activeTabID
        )
        workspaces[projectID] = Workspace(projectID: projectID, worktreeID: workspace.worktreeID, focusedAreaID: areaID, root: .tabArea(updatedArea))
    }

    private func selectTab(projectID: UUID, areaID: UUID, tabID: UUID) throws {
        guard let workspace = workspaces[projectID], case let .tabArea(area) = workspace.root, area.id == areaID else { throw DemoError.notFound }
        guard area.tabs.contains(where: { $0.id == tabID }) else { throw DemoError.notFound }
        let updatedArea = TabArea(id: area.id, projectPath: area.projectPath, tabs: area.tabs, activeTabID: tabID)
        workspaces[projectID] = Workspace(projectID: projectID, worktreeID: workspace.worktreeID, focusedAreaID: areaID, root: .tabArea(updatedArea))
    }

    private static func makeWorkspace(_ seed: DemoProjectSeed) -> Workspace {
        let tabs = seed.tabs.map(\.tab)
        let area = TabArea(id: seed.areaID, projectPath: seed.project.path, tabs: tabs, activeTabID: tabs.first?.id)
        return Workspace(projectID: seed.project.id, worktreeID: seed.worktreeID, focusedAreaID: seed.areaID, root: .tabArea(area))
    }

    private func tagged<T: Encodable & Sendable>(_ type: String, _ value: T) throws -> RawTagged {
        try RawTagged(type: type, value: value)
    }

    private func event<T: Encodable & Sendable>(_ name: String, _ type: String, _ value: T) throws -> EventEnvelope {
        try EventEnvelope(event: name, data: RawTagged(type: type, value: value))
    }

    private func decode<T: Decodable, P: Encodable>(_ type: T.Type, from params: P?) throws -> T {
        guard let params else { throw DemoError.invalidParams }
        let data = try JSONEncoder().encode(params)
        return try JSONDecoder().decode(type, from: data)
    }

    private func projectID(from value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else { throw DemoError.invalidParams }
        return id
    }

    private func areaID(from value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else { throw DemoError.invalidParams }
        return id
    }

    private func tabID(from value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else { throw DemoError.invalidParams }
        return id
    }

    private func paneID(from value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else { throw DemoError.invalidParams }
        return id
    }
}

nonisolated private struct EmptyDemoResult: Codable, Sendable {}

enum DemoError: Error, Sendable {
    case invalidParams
    case notFound
}
