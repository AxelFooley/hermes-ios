import XCTest
@testable import HermesKit

final class MockConnection: GatewayConnection, @unchecked Sendable {
    var sent: [String] = []
    private let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    func connect() async throws {}

    func send(_ text: String) async throws {
        sent.append(text)
    }

    func messages() -> AsyncStream<String> {
        AsyncStream { continuation in
            for line in self.lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }

    func close() async {}
}

final class RPCAndClientTests: XCTestCase {
    func testRequestEncoding() {
        let request = RPCRequest(id: 7, method: "config.get", params: ["scope": .string("full")])
        let encoded = request.encoded()
        XCTAssertTrue(encoded.contains(#""method":"config.get""#))
        XCTAssertTrue(encoded.contains(#""id":7"#))
        XCTAssertTrue(encoded.contains(#""jsonrpc":"2.0""#))
    }

    func testResponseParsing() {
        let ok = RPCResponse(line: #"{"jsonrpc":"2.0","id":1,"result":{"ok":true}}"#)
        XCTAssertEqual(ok?.id, 1)
        XCTAssertEqual(ok?.error, nil)
        XCTAssertEqual(ok?.result?["ok"]?.boolValue, true)

        let failure = RPCResponse(line: #"{"jsonrpc":"2.0","id":2,"error":{"code":404,"message":"nope"}}"#)
        XCTAssertEqual(failure?.error?.code, 404)
        XCTAssertEqual(failure?.error?.message, "nope")
    }

    func testClientCorrelatesResponses() async throws {
        let mock = MockConnection(lines: [
            #"{"jsonrpc":"2.0","id":1,"result":{"interface":"tui"}}"#,
            #"{"jsonrpc":"2.0","id":2,"error":{"code":404,"message":"unknown command"}}"#,
            #"{"type":"gateway.ready","skin":{}}"#,
        ])
        let client = GatewayClient { mock }
        let runTask = Task { await client.run() }
        defer { runTask.cancel() }

        var waited = 0
        while await client.state != .ready, waited < 100 {
            try await Task.sleep(for: .milliseconds(20))
            waited += 1
        }
        guard await client.state == .ready else {
            return XCTFail("client never became ready")
        }

        let result = try await client.request("config.get")
        XCTAssertEqual(result["interface"]?.stringValue, "tui")

        do {
            _ = try await client.request("bogus.command")
            XCTFail("expected RPC error")
        } catch let error as RPCError {
            XCTAssertEqual(error.message, "unknown command")
        }
    }

    func testClientFailsAfterReconnectBudget() async throws {
        let client = GatewayClient { MockConnection(lines: []) }
        let runTask = Task { await client.run() }
        await runTask.value
        if case .failed = await client.state {} else {
            XCTFail("expected failed state, got \(await client.state)")
        }
    }
}
