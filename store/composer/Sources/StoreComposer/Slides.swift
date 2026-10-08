import Foundation

enum SlideLayout {
    case single(String)
    case pair(front: String, back: String)
    case bands([String])

    var shots: [String] {
        switch self {
        case let .single(shot): [shot]
        case let .pair(front, back): [front, back]
        case let .bands(shots): shots
        }
    }
}

struct Slide {
    let id: String
    let eyebrow: String
    let title: [String]
    let highlight: String
    let subtitle: String
    let layout: SlideLayout

    static func all(for target: StoreTarget) -> [Slide] {
        [
            Slide(
                id: "01-agents",
                eyebrow: "Muxy for \(target.platformName)",
                title: ["Your Mac terminal.", "In your pocket."],
                highlight: "In your pocket.",
                subtitle: "Check on coding agents and keep them moving from anywhere.",
                layout: .single("agent")
            ),
            Slide(
                id: "02-projects",
                eyebrow: "Projects",
                title: ["Every project,", "one tap away"],
                highlight: "one tap away",
                subtitle: "Jump between projects and workspaces on your Mac.",
                layout: .single("projects")
            ),
            Slide(
                id: "03-tuis",
                eyebrow: "Terminal",
                title: ["Every TUI", "just works"],
                highlight: "just works",
                subtitle: "Editors, agents and dev servers in full color, with a real keyboard.",
                layout: .pair(front: "editor", back: "dev")
            ),
            Slide(
                id: "04-git",
                eyebrow: "Git",
                title: ["Ship from", "anywhere"],
                highlight: "anywhere",
                subtitle: "Commit, push and track pull requests on the go.",
                layout: .single("git")
            ),
            Slide(
                id: "05-review",
                eyebrow: "Code Review",
                title: ["Review every", "change"],
                highlight: "change",
                subtitle: "Clear diffs for every file your agent touched.",
                layout: .single("diff")
            ),
            Slide(
                id: "06-files",
                eyebrow: "Files",
                title: ["Browse and", "edit files"],
                highlight: "edit files",
                subtitle: "Find a file, fix a line and save it straight to your Mac.",
                layout: .pair(front: "preview", back: "files")
            ),
            Slide(
                id: "07-themes",
                eyebrow: "Themes",
                title: ["Make it", "yours"],
                highlight: "yours",
                subtitle: "12 terminal themes, from Tokyo Night to Gruvbox.",
                layout: .bands(["editor", "theme-editor-catppuccin-latte", "theme-editor-tokyonight", "theme-editor-gruvbox-dark"])
            )
        ]
    }
}
