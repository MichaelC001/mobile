import Foundation

nonisolated enum DemoSources {
    static let tabStorePath = "Sources/Muxy/Tabs/TabStore.swift"
    static let keyboardShortcutsPath = "Sources/Muxy/Input/KeyboardShortcuts.swift"
    static let tabStoreTestsPath = "Tests/MuxyTests/TabStoreTests.swift"
    static let changelogPath = "CHANGELOG.md"

    static let tabStore = """
    import Foundation

    @MainActor
    @Observable
    final class TabStore {
        private(set) var tabs: [Tab] = []
        private(set) var selectedTab: Tab?
        private var closedTabs: [ClosedTab] = []
        private let closedTabLimit = 10

        func open(_ tab: Tab) {
            tabs.insert(tab, at: tabs.endIndex)
            select(tab)
        }

        func close(_ tab: Tab) {
            guard let index = tabs.firstIndex(of: tab) else { return }
            let closed = tabs.remove(at: index)
            closedTabs.append(ClosedTab(tab: closed, index: index))
            closedTabs = Array(closedTabs.suffix(closedTabLimit))
            focusNeighbour(of: index)
        }

        func reopenLastClosed() {
            guard let closed = closedTabs.popLast() else { return }
            let index = min(closed.index, tabs.endIndex)
            tabs.insert(closed.tab, at: index)
            select(closed.tab)
        }

        func select(_ tab: Tab) {
            selectedTab = tab
        }

        private func focusNeighbour(of index: Int) {
            guard !tabs.isEmpty else {
                selectedTab = nil
                return
            }
            select(tabs[min(index, tabs.count - 1)])
        }
    }

    private struct ClosedTab {
        let tab: Tab
        let index: Int
    }

    """

    static let tabStoreDiff = """
    @@ -5,17 +5,27 @@ import Foundation
     final class TabStore {
         private(set) var tabs: [Tab] = []
         private(set) var selectedTab: Tab?
    -    private var lastClosed: Tab?
    +    private var closedTabs: [ClosedTab] = []
    +    private let closedTabLimit = 10

         func open(_ tab: Tab) {
             tabs.insert(tab, at: tabs.endIndex)
             select(tab)
         }

         func close(_ tab: Tab) {
             guard let index = tabs.firstIndex(of: tab) else { return }
    -        lastClosed = tabs.remove(at: index)
    +        let closed = tabs.remove(at: index)
    +        closedTabs.append(ClosedTab(tab: closed, index: index))
    +        closedTabs = Array(closedTabs.suffix(closedTabLimit))
             focusNeighbour(of: index)
         }

    +    func reopenLastClosed() {
    +        guard let closed = closedTabs.popLast() else { return }
    +        let index = min(closed.index, tabs.endIndex)
    +        tabs.insert(closed.tab, at: index)
    +        select(closed.tab)
    +    }
    +
         func select(_ tab: Tab) {
    @@ -30,3 +40,8 @@ final class TabStore {
             select(tabs[min(index, tabs.count - 1)])
         }
     }
    +
    +private struct ClosedTab {
    +    let tab: Tab
    +    let index: Int
    +}
    """

    static let keyboardShortcuts = """
    import SwiftUI

    enum KeyboardShortcuts {
        static let all: [TabShortcut] = [
            TabShortcut("t", modifiers: .command) { tabs in
                tabs.openNew()
            },
            TabShortcut("w", modifiers: .command) { tabs in
                tabs.closeSelected()
            },
            TabShortcut("t", modifiers: [.command, .shift]) { tabs in
                tabs.reopenLastClosed()
            },
            TabShortcut("]", modifiers: [.command, .shift]) { tabs in
                tabs.selectNext()
            }
        ]
    }

    """

    static let keyboardShortcutsDiff = """
    @@ -9,6 +9,9 @@ enum KeyboardShortcuts {
             TabShortcut("w", modifiers: .command) { tabs in
                 tabs.closeSelected()
             },
    +        TabShortcut("t", modifiers: [.command, .shift]) { tabs in
    +            tabs.reopenLastClosed()
    +        },
             TabShortcut("]", modifiers: [.command, .shift]) { tabs in
                 tabs.selectNext()
             }
    """

    static let tabStoreTests = """
    import Testing
    @testable import Muxy

    @MainActor
    struct TabStoreTests {
        @Test func reopensLastClosedTabAtItsPosition() {
            let store = TabStore()
            let tabs = (1...3).map { Tab(title: "zsh \\($0)") }
            tabs.forEach(store.open)

            store.close(tabs[1])
            store.reopenLastClosed()

            #expect(store.tabs == tabs)
            #expect(store.selectedTab == tabs[1])
        }

        @Test func reopensInReverseClosingOrder() {
            let store = TabStore()
            let tabs = (1...3).map { Tab(title: "zsh \\($0)") }
            tabs.forEach(store.open)

            store.close(tabs[0])
            store.close(tabs[2])
            store.reopenLastClosed()

            #expect(store.tabs == [tabs[1], tabs[2]])
        }

        @Test func reopenWithNothingClosedKeepsTabs() {
            let store = TabStore()
            store.open(Tab(title: "zsh"))

            store.reopenLastClosed()

            #expect(store.tabs.count == 1)
        }
    }

    """

    static let changelog = """
    # Changelog

    ## Unreleased

    - Reopen the last closed tab with Cmd+Shift+T.

    ## 1.4.0

    - Split panes can be resized from the keyboard.
    - Faster startup for projects with many worktrees.

    """

    static let changelogDiff = """
    @@ -1,5 +1,9 @@
     # Changelog

    +## Unreleased
    +
    +- Reopen the last closed tab with Cmd+Shift+T.
    +
     ## 1.4.0

     - Split panes can be resized from the keyboard.
    """

    static let readme = """
    # Muxy

    Browse project files, make a quick edit, and return to your terminal. Files are read from the active worktree, so you can keep working wherever you are.

    ## Working with files

    Tap a folder to open it. Touch and hold a file to select it, then use the actions below to rename, move, or delete it.

    ## Reading and editing

    Long lines wrap to fit the screen. Use the wrapping control to keep code on one line, or tap Edit file to make changes. Your edits are saved only when you choose Save changes.

    """

    static let package = """
    // swift-tools-version: 6.0
    import PackageDescription

    let package = Package(
        name: "Muxy",
        platforms: [.macOS(.v15)],
        targets: [
            .executableTarget(name: "Muxy"),
            .testTarget(name: "MuxyTests", dependencies: ["Muxy"])
        ]
    )

    """

    static let continuousIntegration = """
    name: CI

    on: [push, pull_request]

    jobs:
      test:
        runs-on: macos-15
        steps:
          - uses: actions/checkout@v4
          - run: swift test

    """

    static let app = """
    import SwiftUI

    @main
    struct MuxyApp: App {
        @State private var tabs = TabStore()

        var body: some Scene {
            WindowGroup {
                TabStripView(store: tabs)
            }
        }
    }

    """

    static let license = """
    MIT License

    Copyright (c) 2026 Muxy

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction.

    """
}
