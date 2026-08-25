import Foundation

@Observable
public final class TurnStore: @unchecked Sendable {
    public struct TranscriptRow: Sendable, Equatable, Identifiable {
        public let id: UUID
        public var role: String
        public var text: String

        public init(role: String, text: String) {
            id = UUID()
            self.role = role
            self.text = text
        }
    }

    public struct ToolActivity: Sendable, Equatable, Identifiable {
        public let id: String
        public var name: String
        public var preview: String?
        public var isRunning: Bool
        public var summary: String?

        public init(id: String, name: String, preview: String? = nil, isRunning: Bool = true, summary: String? = nil) {
            self.id = id
            self.name = name
            self.preview = preview
            self.isRunning = isRunning
            self.summary = summary
        }
    }

    public private(set) var transcript: [TranscriptRow] = []
    public private(set) var streamingText: String?
    public private(set) var tools: [ToolActivity] = []
    public private(set) var statusText: String = "starting agent…"
    public private(set) var isBusy = false
    public private(set) var queue: [String] = []

    public init() {}

    public func apply(_ event: GatewayEvent) {
        switch event.type {
        case "message.start":
            isBusy = true
            streamingText = ""
        case "message.delta":
            streamingText = (streamingText ?? "") + (event.text("text") ?? "")
        case "message.complete":
            let text = event.text("text") ?? streamingText ?? ""
            transcript.append(TranscriptRow(role: "assistant", text: text))
            streamingText = nil
            isBusy = false
        case "status.update":
            if let text = event.text("text") {
                statusText = text
            }
        case "tool.start":
            if let id = event.text("tool_id"), let name = event.text("name") {
                tools.append(ToolActivity(id: id, name: name, preview: event.text("args_text")))
            }
        case "tool.progress":
            if let name = event.text("name"), let index = tools.lastIndex(where: { $0.name == name && $0.isRunning }) {
                tools[index].preview = event.text("preview")
            }
        case "tool.complete":
            let toolID = event.text("tool_id")
            let name = event.text("name")
            if let index = tools.lastIndex(where: { $0.id == toolID || $0.name == name }) {
                tools[index].isRunning = false
                tools[index].summary = event.text("summary")
            }
        case "error":
            if let message = event.text("message") {
                statusText = "error: \(message)"
            }
        default:
            break
        }
    }

    public func userSent(_ text: String) {
        transcript.append(TranscriptRow(role: "user", text: text))
    }

    public func enqueue(_ text: String) {
        queue.append(text)
    }

    public func drain() -> String? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    public func replaceQueueItem(at index: Int, with text: String) {
        guard queue.indices.contains(index) else { return }
        queue[index] = text
    }

    public func removeQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        queue.remove(at: index)
    }
}
