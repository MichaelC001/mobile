package com.muxy.app.features.demo

import com.muxy.app.core.serialization.parseUuid
import com.muxy.app.core.serialization.uuidString
import com.muxy.app.models.Tab
import com.muxy.app.models.TabArea
import com.muxy.app.models.TabKind
import com.muxy.app.models.Workspace
import com.muxy.app.models.WorkspaceNode
import com.muxy.app.networking.muxy1.protocol.CloseTabParams
import com.muxy.app.networking.muxy1.protocol.CreateTabParams
import com.muxy.app.networking.muxy1.protocol.EmptyResult
import com.muxy.app.networking.muxy1.protocol.ErrorCode
import com.muxy.app.networking.muxy1.protocol.EventEnvelope
import com.muxy.app.networking.muxy1.protocol.EventName
import com.muxy.app.networking.muxy1.protocol.EventType
import com.muxy.app.networking.muxy1.protocol.GetWorkspaceParams
import com.muxy.app.networking.muxy1.protocol.Method
import com.muxy.app.networking.muxy1.protocol.PairingResult
import com.muxy.app.networking.muxy1.protocol.PaneOwner
import com.muxy.app.networking.muxy1.protocol.PaneOwnershipEvent
import com.muxy.app.networking.muxy1.protocol.ProjectsResult
import com.muxy.app.networking.muxy1.protocol.ProtocolException
import com.muxy.app.networking.muxy1.protocol.ProtocolJson
import com.muxy.app.networking.muxy1.protocol.RawTagged
import com.muxy.app.networking.muxy1.protocol.ResultType
import com.muxy.app.networking.muxy1.protocol.SelectTabParams
import com.muxy.app.networking.muxy1.protocol.SelectWorktreeParams
import com.muxy.app.networking.muxy1.protocol.TakeOverPaneParams
import com.muxy.app.networking.muxy1.protocol.TerminalBytesEvent
import com.muxy.app.networking.muxy1.protocol.TerminalInputParams
import com.muxy.app.networking.muxy1.protocol.TerminalResizeParams
import com.muxy.app.networking.muxy1.protocol.VcsProjectParams
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonElement
import java.util.UUID

data class DemoReply(
    val result: RawTagged,
    val events: List<EventEnvelope> = emptyList(),
)

class DemoBackend {
    private val mutex = Mutex()
    private val seeds = DemoCatalog.projects
    private val projects = seeds.map { it.project }
    private val workspaces = seeds.associate { it.project.id to initialWorkspace(it) }.toMutableMap()
    private val paneScreens =
        seeds
            .flatMap { it.tabs }
            .mapNotNull { seed -> seed.tab.paneId?.let { it to seed.screen } }
            .toMap()
    private var tabCounter = 2
    private val shell = DemoShell()
    private val tools = seeds.associate { it.project.id to DemoProjectTools(it.project, it.worktreeId, it.git, it.files) }

    val clientId: UUID = CLIENT_ID

    fun authenticate(): RawTagged = RawTagged.of(ResultType.PAIRING, PairingResult(clientId.uuidString, DemoConnection.NAME))

    suspend fun handle(
        method: Method,
        params: JsonElement?,
    ): DemoReply =
        mutex.withLock {
            when (method) {
                Method.AUTHENTICATE_DEVICE -> {
                    DemoReply(authenticate())
                }

                Method.LIST_PROJECTS -> {
                    DemoReply(RawTagged.of(ResultType.PROJECTS, ProjectsResult(projects)))
                }

                Method.SELECT_PROJECT -> {
                    DemoReply(ok())
                }

                Method.GET_WORKSPACE -> {
                    DemoReply(
                        RawTagged.of(ResultType.WORKSPACE, workspace(decode(GetWorkspaceParams.serializer(), params).projectId)),
                    )
                }

                Method.CREATE_TAB -> {
                    createTab(decode(CreateTabParams.serializer(), params))
                }

                Method.CLOSE_TAB -> {
                    closeTab(decode(CloseTabParams.serializer(), params))
                }

                Method.SELECT_TAB -> {
                    selectTab(decode(SelectTabParams.serializer(), params))
                }

                Method.TAKE_OVER_PANE -> {
                    takeOverPane(decode(TakeOverPaneParams.serializer(), params))
                }

                Method.TERMINAL_INPUT -> {
                    terminalInput(decode(TerminalInputParams.serializer(), params))
                }

                Method.TERMINAL_RESIZE -> {
                    terminalResize(decode(TerminalResizeParams.serializer(), params))
                }

                Method.RELEASE_PANE, Method.SET_CLIENT_THEME, Method.TERMINAL_SCROLL -> {
                    DemoReply(ok())
                }

                Method.PAIR_DEVICE, Method.GET_PROJECT_LOGO -> {
                    throw notFound()
                }

                Method.LIST_WORKTREES, Method.SELECT_WORKTREE,
                Method.FILES_LIST, Method.FILES_STAT, Method.FILES_READ, Method.FILES_WRITE,
                Method.FILES_MKDIR, Method.FILES_RENAME, Method.FILES_MOVE, Method.FILES_DELETE,
                Method.VCS_REFRESH, Method.VCS_LIST_BRANCHES, Method.VCS_GET_DIFF, Method.VCS_COMMIT,
                Method.VCS_PULL, Method.VCS_PUSH, Method.VCS_SWITCH_BRANCH, Method.VCS_CREATE_BRANCH,
                Method.VCS_CREATE_PR, Method.VCS_MERGE_PULL_REQUEST, Method.VCS_ADD_WORKTREE, Method.VCS_REMOVE_WORKTREE,
                -> {
                    projectTool(method, params)
                }
            }
        }

    private suspend fun projectTool(
        method: Method,
        params: JsonElement?,
    ): DemoReply {
        val projectId = uuid(DemoRequest.decode<VcsProjectParams>(params).projectId)
        val workspace = workspaces[projectId] ?: throw notFound()
        val projectTools = tools[projectId] ?: throw notFound()
        val reply = withContext(Dispatchers.Default) { projectTools.handle(method, params, workspace.worktreeId) }
        if (method != Method.SELECT_WORKTREE) return reply
        val worktreeId = uuid(DemoRequest.decode<SelectWorktreeParams>(params).worktreeId)
        workspaces[projectId] = workspace.copy(worktreeId = worktreeId)
        return reply.copy(events = reply.events + workspaceEvents(projectId))
    }

    private fun takeOverPane(params: TakeOverPaneParams): DemoReply {
        val paneId = uuid(params.paneId)
        val ownership = PaneOwnershipEvent(paneId, PaneOwner.Remote(clientId, DEMO_DEVICE_NAME))
        val screen = paneScreens[paneId] ?: DemoTerminalScreen.SHELL
        val contents = if (screen == DemoTerminalScreen.SHELL) shell.open(paneId) else screen.render(params.cols, params.rows)
        return DemoReply(
            ok(),
            listOf(
                EventEnvelope(EventName.PANE_OWNERSHIP_CHANGED, RawTagged.of(EventType.PANE_OWNERSHIP, ownership)),
                snapshotEvent(paneId, contents),
            ),
        )
    }

    private fun terminalResize(params: TerminalResizeParams): DemoReply {
        val paneId = uuid(params.paneId)
        val screen = paneScreens[paneId] ?: DemoTerminalScreen.SHELL
        if (!screen.redrawsOnResize) return DemoReply(ok())
        return DemoReply(ok(), listOf(snapshotEvent(paneId, screen.render(params.cols, params.rows))))
    }

    private fun snapshotEvent(
        paneId: UUID,
        contents: String,
    ): EventEnvelope =
        EventEnvelope(
            EventName.TERMINAL_SNAPSHOT,
            RawTagged.of(EventType.TERMINAL_SNAPSHOT, TerminalBytesEvent(paneId, contents.toByteArray())),
        )

    private fun terminalInput(params: TerminalInputParams): DemoReply {
        val paneId = uuid(params.paneId)
        val output = shell.input(paneId, params.bytes.decodeToString())
        if (output.isEmpty()) return DemoReply(ok())
        val event = TerminalBytesEvent(paneId, output.toByteArray())
        return DemoReply(ok(), listOf(EventEnvelope(EventName.TERMINAL_OUTPUT, RawTagged.of(EventType.TERMINAL_OUTPUT, event))))
    }

    private fun createTab(params: CreateTabParams): DemoReply {
        val projectId = uuid(params.projectId)
        val workspace = workspace(params.projectId)
        val area = rootArea(workspace)
        if (params.areaId != null && parseUuid(params.areaId) != area.id) throw notFound()
        tabCounter += 1
        val tab = Tab(UUID.randomUUID(), TabKind.Terminal, "zsh $tabCounter", false, UUID.randomUUID())
        val updated = area.copy(tabs = area.tabs + tab, activeTabId = tab.id)
        workspaces[projectId] = workspace.copy(focusedAreaId = updated.id, root = WorkspaceNode.Area(updated))
        return DemoReply(RawTagged.of(ResultType.TAB, tab), workspaceEvents(projectId))
    }

    private fun closeTab(params: CloseTabParams): DemoReply {
        val projectId = uuid(params.projectId)
        val workspace = workspace(params.projectId)
        val area = rootArea(workspace)
        val tabId = uuid(params.tabId)
        if (area.id != uuid(params.areaId)) throw notFound()
        val tabs = area.tabs.filterNot { it.id == tabId }
        val activeTabId = if (area.activeTabId == tabId) tabs.firstOrNull()?.id else area.activeTabId
        val updated = area.copy(tabs = tabs, activeTabId = activeTabId)
        workspaces[projectId] = workspace.copy(focusedAreaId = area.id, root = WorkspaceNode.Area(updated))
        return DemoReply(ok(), workspaceEvents(projectId))
    }

    private fun selectTab(params: SelectTabParams): DemoReply {
        val projectId = uuid(params.projectId)
        val workspace = workspace(params.projectId)
        val area = rootArea(workspace)
        val tabId = uuid(params.tabId)
        if (area.id != uuid(params.areaId) || area.tabs.none { it.id == tabId }) throw notFound()
        workspaces[projectId] = workspace.copy(focusedAreaId = area.id, root = WorkspaceNode.Area(area.copy(activeTabId = tabId)))
        return DemoReply(ok(), workspaceEvents(projectId))
    }

    private fun workspace(projectId: String): Workspace = workspaces[uuid(projectId)] ?: throw notFound()

    private fun rootArea(workspace: Workspace): TabArea = (workspace.root as? WorkspaceNode.Area)?.area ?: throw notFound()

    private fun workspaceEvents(projectId: UUID): List<EventEnvelope> {
        val workspace = workspaces[projectId] ?: throw notFound()
        return listOf(EventEnvelope(EventName.WORKSPACE_CHANGED, RawTagged.of(EventType.WORKSPACE, workspace)))
    }

    private fun ok(): RawTagged = RawTagged.of(ResultType.OK, EmptyResult())

    private fun <T> decode(
        deserializer: DeserializationStrategy<T>,
        params: JsonElement?,
    ): T {
        params ?: throw invalidParams()
        return try {
            ProtocolJson.decodeFromJsonElement(deserializer, params)
        } catch (error: SerializationException) {
            throw invalidParams()
        } catch (error: IllegalArgumentException) {
            throw invalidParams()
        }
    }

    private fun uuid(value: String): UUID = parseUuid(value) ?: throw invalidParams()

    private fun notFound() = ProtocolException(ErrorCode.NOT_FOUND.body("Not available in demo mode"))

    private fun invalidParams() = ProtocolException(ErrorCode.INVALID_PARAMS.body("Invalid demo request"))

    private companion object {
        val CLIENT_ID: UUID = UUID.fromString("00000000-0000-4000-8000-000000000101")
        const val DEMO_DEVICE_NAME = "Android (Demo)"

        fun initialWorkspace(seed: DemoProjectSeed): Workspace {
            val tabs = seed.tabs.map { it.tab }
            return Workspace(
                projectId = seed.project.id,
                worktreeId = seed.worktreeId,
                focusedAreaId = seed.areaId,
                root = WorkspaceNode.Area(TabArea(seed.areaId, seed.project.path, tabs, tabs.firstOrNull()?.id)),
            )
        }
    }
}
