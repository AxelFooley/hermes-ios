import Foundation

public protocol GatewayConnection: Sendable {
    func connect() async throws
    func send(_ text: String) async throws
    func messages() -> AsyncStream<String>
    func close() async
}

public final class WebSocketConnection: GatewayConnection, @unchecked Sendable {
    private let url: URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var continuation: AsyncStream<String>.Continuation?

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    public func connect() async throws {
        task = session.webSocketTask(with: url)
        task?.resume()
    }

    public func send(_ text: String) async throws {
        guard let task else { throw RPCError(code: -1, message: "connection not open") }
        try await task.send(.string(text))
    }

    public func messages() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
            pump()
        }
    }

    public func close() async {
        continuation?.finish()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func pump() {
        guard let task else {
            continuation?.finish()
            return
        }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let text)):
                self.continuation?.yield(text)
                self.pump()
            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.continuation?.yield(text)
                }
                self.pump()
            case .success:
                self.pump()
            case .failure:
                self.continuation?.finish()
            }
        }
    }
}

public enum Connections {
    public static func serve(url: URL) -> WebSocketConnection {
        WebSocketConnection(url: websocketURL(from: url, path: ""))
    }

    public static func dashboard(base: URL, session: URLSession = .shared) async throws -> WebSocketConnection {
        let token = try await dashboardToken(base: base, session: session)
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/api/ws"
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else {
            throw RPCError(code: -1, message: "invalid dashboard URL")
        }
        return WebSocketConnection(url: url)
    }

    static func dashboardToken(base: URL, session: URLSession) async throws -> String {
        guard let htmlURL = URL(string: base.absoluteString) else {
            throw RPCError(code: -1, message: "invalid dashboard URL")
        }
        let (data, _) = try await session.data(from: htmlURL)
        guard let html = String(data: data, encoding: .utf8) else {
            throw RPCError(code: -1, message: "dashboard returned non-UTF8 response")
        }
        let patterns = [
            #"__HERMES_SESSION_TOKEN__\s*=\s*"([^"]+)""#,
            #"[?&]token=([A-Za-z0-9._\-]+)"#
        ]
        for pattern in patterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let captured = captureGroup(from: String(html[match]), in: pattern, source: html, range: match)
                if !captured.isEmpty { return captured }
            }
        }
        throw RPCError(code: -1, message: "no session token found in dashboard HTML")
    }

    private static func captureGroup(from match: String, in pattern: String, source: String, range: Range<String.Index>) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let nsRange = NSRange(range, in: source)
        guard let capture = regex.firstMatch(in: source, range: nsRange)?.range(at: 1),
              capture.location != NSNotFound,
              let group = Range(capture, in: source) else { return "" }
        return String(source[group])
    }

    static func websocketURL(from url: URL, path: String) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = path
        return comps.url ?? url
    }
}
