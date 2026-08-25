import SwiftUI
import HermesKit

private let palette = HermesPalette.standard

struct BannerCard: View {
    @State private var toolsOpen = true
    @State private var skillsOpen = false
    @State private var promptOpen = false
    @State private var mcpOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("⚕ hermes-agent")
                .font(.headline)
                .foregroundStyle(palette.primary)
            section("Tools", open: $toolsOpen) {
                toolChips(["terminal", "browser", "files", "memory"])
            }
            section("Skills", open: $skillsOpen) {}
            section("System Prompt", open: $promptOpen) {}
            section("MCP Servers", open: $mcpOpen) {}
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.border.opacity(0.6), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func section(_ title: String, open: Binding<Bool>, content: () -> some View) -> some View {
        DisclosureGroup(isExpanded: open) {
            content()
                .padding(.leading, 14)
                .padding(.top, 4)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.label)
        }
        .tint(palette.accent)
    }

    private func toolChips(_ names: [String]) -> some View {
        FlowChips(names: names)
    }
}

struct FlowChips: View {
    let names: [String]

    var body: some View {
        FlexibleWrap(chips: names.map { chip in
            HStack(spacing: 4) {
                Circle().fill(palette.ok).frame(width: 6, height: 6)
                Text(chip).font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(palette.surface.opacity(0.7))
            .overlay(
                Capsule().stroke(palette.border.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
            .foregroundStyle(palette.text)
        })
    }
}

struct FlexibleWrap<Chip: View>: View {
    let chips: [Chip]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 5) {
            ForEach(0..<chips.count, id: \.self) { index in
                chips[index]
            }
        }
    }
}

struct TranscriptRowView: View {
    let row: TurnStore.TranscriptRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.role == "user" ? "you ❯" : "hermes ⚕")
                .font(.caption2.monospaced())
                .foregroundStyle(row.role == "user" ? palette.primary : palette.accent)
            textBlock
        }
    }

    private var textBlock: some View {
        Text(MarkdownRenderer.render(row.text))
            .font(.body)
            .foregroundStyle(palette.text)
            .textSelection(.enabled)
    }
}

struct StreamingBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("hermes ⚕")
                .font(.caption2.monospaced())
                .foregroundStyle(palette.accent)
            Text(MarkdownRenderer.render(text) + AttributedString(" ▍"))
                .font(.body)
                .foregroundStyle(palette.text)
        }
    }
}

struct ToolCard: View {
    let tool: TurnStore.ToolActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("▾ ┊ \(tool.name)")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(palette.accent)
                if tool.isRunning {
                    TimelineView(.periodic(from: .now, by: 2.5)) { context in
                        Text(Kaomoji.face(after: tick(context.date)))
                            .font(.caption2)
                            .foregroundStyle(palette.warn)
                    }
                }
            }
            if let preview = tool.preview {
                Text(preview)
                    .font(.caption.monospaced())
                    .foregroundStyle(palette.shellDollar)
                    .lineLimit(3)
            }
            if let summary = tool.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle().fill(palette.accent).frame(width: 3)
        }
    }

    private func tick(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 2.5)
    }
}

struct QueueChipsView: View {
    @Environment(ChatModel.self) private var model

    var body: some View {
        if !model.store.queue.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(model.store.queue.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 4) {
                            Text("\(index + 1)").foregroundStyle(palette.muted)
                            Text(item).lineLimit(1)
                            Button {
                                model.store.removeQueueItem(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.caption2)
                            }
                            .tint(palette.muted)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(palette.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.border.opacity(0.4), lineWidth: 1))
                    }
                }
            }
        }
    }
}

struct StatusCapsuleView: View {
    @Environment(ChatModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isConnected ? palette.ok : palette.warn)
                .frame(width: 7, height: 7)
            Text(model.statusText)
                .lineLimit(1)
            if model.store.isBusy {
                Text("▶ \(model.store.queue.count) queued").foregroundStyle(palette.muted)
            }
            Spacer(minLength: 0)
        }
        .font(.caption2.monospaced())
        .foregroundStyle(palette.statusFg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(palette.surface.opacity(0.6))
        .clipShape(Capsule())
    }
}

struct ComposerView: View {
    @Bindable var model: ChatModel

    var body: some View {
        VStack(spacing: 6) {
            if model.draft.hasPrefix("/") {
                SlashAutocompleteView(draft: $model.draft)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Text("❯")
                    .font(.body.monospaced().weight(.bold))
                    .foregroundStyle(palette.primary)
                TextField("Type your message or /help for commands.", text: $model.draft, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...5)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { model.submit() }
                controls
            }
            .padding(10)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if model.store.isBusy {
                Button(role: .destructive) {
                    model.interrupt()
                } label: {
                    Image(systemName: "stop.fill")
                }
            }
            Button {
                model.draft.append("\n")
            } label: {
                Image(systemName: "arrow.turn.down.left")
            }
            Button {
                model.submit()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .font(.body)
        .tint(palette.primary)
    }
}

struct SlashAutocompleteView: View {
    @Binding var draft: String

    static let commands: [(String, String)] = [
        ("/help", "categorized command overlay"),
        ("/model", "switch model — grouped by provider"),
        ("/sessions", "live session switcher"),
        ("/resume", "resume a saved session"),
        ("/usage", "token / cost / context panel"),
        ("/agents", "live subagent tree"),
        ("/skills", "skills hub"),
        ("/skin", "theme with live preview"),
        ("/details", "tool/thinking detail modes"),
        ("/queue", "queued input preview"),
        ("/clear", "new session"),
        ("/voice", "voice mode"),
        ("/yolo", "auto-approve toggle"),
        ("/compress", "compress session context"),
    ]

    var body: some View {
        let query = draft.lowercased()
        let matches = Self.commands.filter { $0.0.hasPrefix(query) }
        if !matches.isEmpty {
            VStack(spacing: 0) {
                ForEach(matches, id: \.0) { command, description in
                    Button {
                        draft = command + " "
                    } label: {
                        HStack {
                            Text(command)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(palette.primary)
                            Text(description)
                                .font(.caption2)
                                .foregroundStyle(palette.statusFg)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border.opacity(0.4), lineWidth: 1))
        }
    }
}
