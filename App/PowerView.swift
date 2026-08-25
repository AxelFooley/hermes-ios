import SwiftUI

struct PowerView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Model & context") {
                    row("Model picker", "bolt.badge.clock", "Switch model — grouped by provider, cost hints")
                    row("Usage", "chart.pie", "Token / cost / context panel")
                }
                Section("Agents") {
                    row("Live agent tree", "tree", "Subagent tree with kill / pause and rollups")
                    row("Replay", "arrow.counterclockwise", "Last 10 subagent fan-outs")
                }
                Section("Runtime") {
                    row("Skills hub", "puzzlepiece", "Installed skills and reload")
                    row("Background tasks", "play.circle", "Running /background tasks")
                    row("Billing & credits", "creditcard", "Nous spending, auto-reload, limits")
                }
            }
            .navigationTitle("Power")
        }
    }

    private func row(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        NavigationLink {
            PanelPlaceholder(title: title)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
            }
        }
    }
}

struct PanelPlaceholder: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer.circle",
            description: Text("Ships with Power panels in Phase 2 — see docs/spec for the full design.")
        )
    }
}
