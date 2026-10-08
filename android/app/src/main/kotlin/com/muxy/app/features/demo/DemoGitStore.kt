package com.muxy.app.features.demo

import com.muxy.app.models.VcsBranches
import com.muxy.app.models.VcsDiff
import com.muxy.app.models.VcsDiffRow
import com.muxy.app.models.VcsDiffRowKind
import com.muxy.app.models.VcsFile
import com.muxy.app.models.VcsPrCreated
import com.muxy.app.models.VcsPullRequest
import com.muxy.app.models.VcsStatus

internal data class DemoGitSeed(
    val branch: String = DemoGitStore.DEFAULT_BRANCH,
    val otherBranches: List<String> = emptyList(),
    val aheadCount: Long = 0,
    val stagedFiles: List<VcsFile> = emptyList(),
    val changedFiles: List<VcsFile> = emptyList(),
    val pullRequests: Map<String, VcsPullRequest> = emptyMap(),
    val diffs: Map<String, String> = emptyMap(),
)

internal class DemoGitStore(
    seed: DemoGitSeed,
) {
    private var branch = seed.branch
    private var aheadCount = seed.aheadCount
    private var behindCount = 0L
    private var hasUpstream = true
    private var stagedFiles = seed.stagedFiles
    private var changedFiles = seed.changedFiles
    private val pullRequests = seed.pullRequests.toMutableMap()
    private val diffs = seed.diffs
    private val localBranches = (listOf(DEFAULT_BRANCH, seed.branch) + seed.otherBranches).distinct().toMutableList()

    val status: VcsStatus
        get() =
            VcsStatus(
                branch = branch,
                aheadCount = aheadCount,
                behindCount = behindCount,
                hasUpstream = hasUpstream,
                stagedFiles = stagedFiles,
                changedFiles = changedFiles,
                defaultBranch = DEFAULT_BRANCH,
                pullRequest = pullRequests[branch],
            )

    fun branches() = VcsBranches(branch, localBranches.toList(), DEFAULT_BRANCH)

    fun commit(
        message: String,
        stageAll: Boolean,
    ) {
        if (message.isBlank()) throw DemoRequest.failure("Enter a commit message.")
        stagedFiles = emptyList()
        if (stageAll) changedFiles = emptyList()
        aheadCount += 1
    }

    fun switchBranch(name: String) {
        if (name !in localBranches) throw DemoRequest.failure("Branch not found.")
        branch = name
    }

    fun createBranch(name: String) {
        if (name.isBlank() || name in localBranches) throw DemoRequest.failure("Choose a unique branch name.")
        localBranches += name
        switchBranch(name)
    }

    fun pull() {
        behindCount = 0
    }

    fun push() {
        aheadCount = 0
        hasUpstream = true
    }

    fun createPullRequest(
        base: String?,
        draft: Boolean,
    ): VcsPrCreated {
        val created = VcsPrCreated("https://github.com/muxy-app/muxy/pull/43", 43)
        pullRequests[branch] = VcsPullRequest(created.url, created.number, "OPEN", draft, base ?: DEFAULT_BRANCH)
        return created
    }

    fun mergePullRequest() {
        val pullRequest = pullRequests[branch] ?: return
        pullRequests[branch] = pullRequest.copy(state = "MERGED")
    }

    fun diff(path: String): VcsDiff = DemoDiffParser.diff(path, diffs[path] ?: FALLBACK_DIFF)

    companion object {
        const val DEFAULT_BRANCH = "main"

        private val FALLBACK_DIFF =
            """
            @@ -1,3 +1,4 @@
             import SwiftUI
            +import Observation

             struct ContentView: View {
            """.trimIndent()
    }
}

internal object DemoDiffParser {
    fun diff(
        filePath: String,
        unified: String,
    ): VcsDiff {
        val rows = mutableListOf<VcsDiffRow>()
        var oldLine = 0L
        var newLine = 0L
        for (line in unified.split("\n")) {
            if (line.startsWith("@@")) {
                val starts = hunkStarts(line)
                oldLine = starts.first
                newLine = starts.second
                rows += VcsDiffRow(VcsDiffRowKind.HUNK, text = line)
                continue
            }
            when (line.firstOrNull()) {
                '+' -> {
                    rows += VcsDiffRow(VcsDiffRowKind.ADDITION, null, newLine, line)
                    newLine += 1
                }

                '-' -> {
                    rows += VcsDiffRow(VcsDiffRowKind.DELETION, oldLine, null, line)
                    oldLine += 1
                }

                else -> {
                    rows += VcsDiffRow(VcsDiffRowKind.CONTEXT, oldLine, newLine, line.ifEmpty { " " })
                    oldLine += 1
                    newLine += 1
                }
            }
        }
        return VcsDiff(
            filePath = filePath,
            rows = rows,
            additions = rows.count { it.kind == VcsDiffRowKind.ADDITION }.toLong(),
            deletions = rows.count { it.kind == VcsDiffRowKind.DELETION }.toLong(),
            truncated = false,
            isBinary = false,
        )
    }

    fun addedFile(content: String): String {
        val lines = content.removeSuffix("\n").split("\n")
        return (listOf("@@ -0,0 +1,${lines.size} @@") + lines.map { "+$it" }).joinToString("\n")
    }

    private fun hunkStarts(header: String): Pair<Long, Long> {
        val ranges =
            header
                .split(" ")
                .drop(1)
                .take(2)
                .map { range -> range.drop(1).substringBefore(",").toLongOrNull() ?: 0L }
        if (ranges.size != 2) return 1L to 1L
        return maxOf(ranges[0], 1L) to maxOf(ranges[1], 1L)
    }
}
