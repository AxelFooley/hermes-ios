import SwiftUI
import HermesKit

struct SessionsView: View {
    @Environment(ChatModel.self) private var model
    @State private var sessions: [SessionRow] = []
    @State private var loadError: String?

    struct SessionRow: Identifiable {
        let id: String
        let title: String
        let detail: String
    }

    var body: some View {
        NavigationStack {
            List {
                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Sessions") {
                    ForEach(sessions) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.body.weight(.medium))
                            Text(row.detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        guard model.isConnected else {
            loadError = "Not connected — add a server in Settings."
            return
        }
        do {
            let result = try await model.request("session.list")
            sessions = Self.parse(result)
            loadError = sessions.isEmpty ? "No sessions returned by the gateway." : nil
        } catch {
            loadError = "session.list failed: \(error.localizedDescription)"
        }
    }

    static func parse(_ result: JSONValue) -> [SessionRow] {
        let items = result.arrayValue ?? result["sessions"]?.arrayValue ?? []
        return items.compactMap { item in
            guard let id = item["id"]?.stringValue ?? item["session_id"]?.stringValue else { return nil }
            let title = item["title"]?.stringValue ?? item["name"]?.stringValue ?? id
            let detail = item["cwd"]?.stringValue ?? item["updated"]?.stringValue ?? ""
            return SessionRow(id: id, title: title, detail: detail)
        }
    }
}
