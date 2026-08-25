import Foundation

public actor GatewayClient {
    public enum State: Sendable, Equatable {
        case idle
        case connecting
        case ready
        case reconnecting(attempts: Int)
        case failed(String)
    }

    public static let maxReconnectAttempts = 3

    private let makeConnection: @Sendable () async throws -> any GatewayConnection
    private var connection: (any GatewayConnection)?
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var eventContinuations: [UUID: AsyncStream<GatewayEvent>.Continuation] = [:]
    public private(set) var state: State = .idle

    public init(makeConnection: @escaping @Sendable () async throws -> any GatewayConnection) {
        self.makeConnection = makeConnection
    }

    public func events() -> AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeEventStream(id) }
            }
        }
    }

    public func run() async {
        var attempts = 0
        while attempts < Self.maxReconnectAttempts {
            state = attempts == 0 ? .connecting : .reconnecting(attempts: attempts)
            do {
                let connection = try await makeConnection()
                try await connection.connect()
                self.connection = connection
                attempts = 0
                state = .ready
                try await receiveLoop()
            } catch {
                failPending(with: error)
            }
            attempts += 1
            if attempts < Self.maxReconnectAttempts {
                let backoff = [1.0, 2.0, 4.0][min(attempts - 1, 2)]
                try? await Task.sleep(for: .seconds(backoff))
            }
        }
        state = .failed("gateway unreachable after \(attempts) attempts")
    }

    public func request(_ method: String, params: [String: JSONValue]? = nil) async throws -> JSONValue {
        guard let connection else {
            throw RPCError(code: -1, message: "not connected")
        }
        nextID += 1
        let id = nextID
        let request = RPCRequest(id: id, method: method, params: params)
        try await connection.send(request.encoded())
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
        }
    }

    public func shutdown() async {
        receiveCleanup()
        await connection?.close()
        connection = nil
    }

    private func receiveLoop() async throws {
        guard let connection else {
            throw RPCError(code: -1, message: "not connected")
        }
        let stream = connection.messages()
        for await line in stream {
            if let response = RPCResponse(line: line) {
                resolve(response)
            } else if let event = GatewayEvent(line: line) {
                for continuation in eventContinuations.values {
                    continuation.yield(event)
                }
            }
        }
        throw RPCError(code: -2, message: "connection closed")
    }

    private func resolve(_ response: RPCResponse) {
        guard let continuation = pending.removeValue(forKey: response.id) else { return }
        if let error = response.error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: response.result ?? .null)
        }
    }

    private func failPending(with error: Error) {
        for continuation in pending.values {
            continuation.resume(throwing: error)
        }
        pending.removeAll()
    }

    private func receiveCleanup() {
        for continuation in eventContinuations.values {
            continuation.finish()
        }
        eventContinuations.removeAll()
        failPending(with: RPCError(code: -1, message: "client shut down"))
    }

    private func removeEventStream(_ id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }
}
