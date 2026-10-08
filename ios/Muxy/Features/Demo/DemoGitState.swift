import Foundation

nonisolated struct DemoGitState: Sendable {
    static let defaultBranch = "main"

    private(set) var branch: String
    private(set) var branches: [String]
    private(set) var aheadCount: Int
    private(set) var stagedFiles: [VCSFile]
    private(set) var changedFiles: [VCSFile]
    private let pullRequests: [String: VCSPullRequest]
    private let diffs: [String: String]

    init(
        branch: String = DemoGitState.defaultBranch,
        otherBranches: [String] = [],
        aheadCount: Int = 0,
        stagedFiles: [VCSFile] = [],
        changedFiles: [VCSFile] = [],
        pullRequests: [String: VCSPullRequest] = [:],
        diffs: [String: String] = [:]
    ) {
        self.branch = branch
        self.aheadCount = aheadCount
        self.stagedFiles = stagedFiles
        self.changedFiles = changedFiles
        self.pullRequests = pullRequests
        self.diffs = diffs
        branches = ([Self.defaultBranch, branch] + otherBranches).reduce(into: []) { result, name in
            if !result.contains(name) { result.append(name) }
        }
    }

    var status: VCSStatus {
        VCSStatus(
            branch: branch,
            aheadCount: aheadCount,
            behindCount: 0,
            hasUpstream: true,
            stagedFiles: stagedFiles,
            changedFiles: changedFiles,
            defaultBranch: Self.defaultBranch,
            pullRequest: pullRequests[branch]
        )
    }

    var branchList: VCSBranches {
        VCSBranches(current: branch, locals: branches, defaultBranch: Self.defaultBranch)
    }

    mutating func commit() {
        stagedFiles = []
        changedFiles = []
        aheadCount += 1
    }

    mutating func checkout(_ name: String) {
        branch = name
        aheadCount = name == Self.defaultBranch ? 0 : aheadCount
        if !branches.contains(name) { branches.append(name) }
    }

    func diff(for path: String, truncated: Bool) -> VCSDiff {
        DemoDiffParser.diff(filePath: path, unified: diffs[path] ?? Self.fallbackDiff, truncated: truncated)
    }

    private static let fallbackDiff = """
    @@ -1,3 +1,4 @@
     import SwiftUI
    +import Observation

     struct ContentView: View {
    """
}

nonisolated enum DemoDiffParser {
    static func diff(filePath: String, unified: String, truncated: Bool) -> VCSDiff {
        var rows: [VCSDiffRow] = []
        var oldLine = 0
        var newLine = 0
        for line in unified.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("@@") {
                (oldLine, newLine) = hunkStarts(line)
                rows.append(VCSDiffRow(kind: .hunk, oldLineNumber: nil, newLineNumber: nil, text: line))
                continue
            }
            switch line.first {
            case "+":
                rows.append(VCSDiffRow(kind: .addition, oldLineNumber: nil, newLineNumber: newLine, text: line))
                newLine += 1
            case "-":
                rows.append(VCSDiffRow(kind: .deletion, oldLineNumber: oldLine, newLineNumber: nil, text: line))
                oldLine += 1
            default:
                rows.append(VCSDiffRow(kind: .context, oldLineNumber: oldLine, newLineNumber: newLine, text: line.isEmpty ? " " : line))
                oldLine += 1
                newLine += 1
            }
        }
        return VCSDiff(
            filePath: filePath,
            rows: rows,
            additions: rows.filter { $0.kind == .addition }.count,
            deletions: rows.filter { $0.kind == .deletion }.count,
            truncated: truncated,
            isBinary: false
        )
    }

    static func addedFile(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).dropLast(content.hasSuffix("\n") ? 1 : 0)
        return (["@@ -0,0 +1,\(lines.count) @@"] + lines.map { "+\($0)" }).joined(separator: "\n")
    }

    private static func hunkStarts(_ header: String) -> (old: Int, new: Int) {
        let ranges = header.split(separator: " ").dropFirst().prefix(2).map { range in
            Int(range.dropFirst().split(separator: ",").first ?? "") ?? 0
        }
        guard ranges.count == 2 else { return (1, 1) }
        return (max(ranges[0], 1), max(ranges[1], 1))
    }
}
