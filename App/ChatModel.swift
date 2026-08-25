import SwiftUI
import HermesKit

@Observable
@MainActor
final class ChatModel {
    let store = TurnStore()
    private(set) var connectionState: GatewayClient.State = .idle
    var draft = ""
    private var client: GatewayClient?
    private var runTask: Task<Void, Never>?

    var statusText: String {
        switch connectionState {
        case .idle: return "idle"
        case .connecting: return "forging session…"
        case .reconnecting: return "resuming…"
        case .failed(let message): return message
        case .ready: return store.statusText
        }
    }

    var isConnected: Bool {
        if case .ready = connectionState { return true }
        return false
    }

    func connect(profile: ConnectionProfile) {
        disconnect()
        let client = GatewayClient(makeConnection: Self.makeConnectionFactory(profile: profile))
        self.client = client
        connectionState = .connecting
        runTask = Task {
            await client.run()
            connectionState = await client.state
        }
        Task {
            let stream = await client.events()
            for await event in stream {
                store.apply(event)
            }
        }
    }

    func disconnect() {
        guard let client else { return }
        runTask?.cancel()
        self.client = nil
        connectionState = .idle
        Task { await client.shutdown() }
    }

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client else { return }
        draft = ""
        if text.hasPrefix("!") {
            store.userSent(text)
            spawn { try await client.request("shell.exec", params: ["command": .string(String(text.dropFirst()))]) }
        } else if store.isBusy {
            store.enqueue(text)
        } else {
            store.userSent(text)
            spawn { try await client.request("message.send", params: ["text": .string(text)]) }
        }
    }

    func interrupt() {
        guard let client else { return }
        spawn { try await client.request("run.interrupt") }
    }

    func request(_ method: String, params: [String: JSONValue]? = nil) async throws -> JSONValue {
        guard let client else {
            throw RPCError(code: -1, message: "not connected")
        }
        return try await client.request(method, params: params)
    }

    private func spawn(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            try? await operation()
        }
    }

    static func makeConnectionFactory(profile: ConnectionProfile) -> @Sendable () async throws -> any GatewayConnection {
        { () async throws -> any GatewayConnection in
            guard let url = URL(string: profile.url) else {
                throw RPCError(code: -1, message: "invalid URL: \(profile.url)")
            }
            switch profile.mode {
            case .serve:
                return Connections.serve(url: url)
            case .dashboard:
                return try await Connections.dashboard(base: url)
            }
        }
    }
}
