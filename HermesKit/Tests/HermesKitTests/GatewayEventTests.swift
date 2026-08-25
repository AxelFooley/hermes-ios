import XCTest
@testable import HermesKit

final class GatewayEventTests: XCTestCase {
    func testParsesWrappedPayload() {
        let line = #"{"type":"message.delta","payload":{"text":"hello"}}"#
        let event = GatewayEvent(line: line)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, "message.delta")
        XCTAssertEqual(event?.text("text"), "hello")
    }

    func testParsesFlattenedPayload() {
        let line = #"{"type":"status.update","kind":"busy","text":"running…"}"#
        let event = GatewayEvent(line: line)
        XCTAssertEqual(event?.type, "status.update")
        XCTAssertEqual(event?.text("text"), "running…")
        XCTAssertEqual(event?.text("kind"), "busy")
    }

    func testRejectsNonEventLines() {
        XCTAssertNil(GatewayEvent(line: #"{"jsonrpc":"2.0","id":1,"result":{}"# + "}"))
        XCTAssertNil(GatewayEvent(line: "not json"))
        XCTAssertNil(GatewayEvent(line: #"{"result":null,"id":3}"#))
    }

    func testTypedPayloadDecoding() {
        struct Delta: Decodable { let text: String }
        let event = GatewayEvent(line: #"{"type":"message.delta","text":"abc"}"#)
        XCTAssertEqual(event?.payload(Delta.self)?.text, "abc")
    }

    func testToolEventRoundTrip() {
        let line = #"{"type":"tool.complete","tool_id":"t1","name":"terminal","summary":"2 passed","duration_s":1.5}"#
        let event = GatewayEvent(line: line)
        XCTAssertEqual(event?.text("tool_id"), "t1")
        XCTAssertEqual(event?.text("summary"), "2 passed")
    }
}
