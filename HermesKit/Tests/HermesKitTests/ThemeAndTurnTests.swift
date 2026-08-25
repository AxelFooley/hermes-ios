import XCTest
@testable import HermesKit

final class ThemeAndTurnTests: XCTestCase {
    func testDarkPaletteMatchesTUISeeds() {
        let theme = Theme.dark
        XCTAssertEqual(theme.color.primary, "#FFD700")
        XCTAssertEqual(theme.color.accent, "#FFBF00")
        XCTAssertEqual(theme.color.border, "#CD7F32")
        XCTAssertEqual(theme.color.text, "#FFF8DC")
        XCTAssertEqual(theme.color.statusBg, "#1a1a2e")
        XCTAssertEqual(theme.color.shellDollar, "#4dabf7")
        XCTAssertEqual(theme.brand.icon, "⚕")
        XCTAssertEqual(theme.brand.promptSymbol, "❯")
        XCTAssertEqual(theme.brand.toolMarker, "┊")
        XCTAssertEqual(theme.brand.helpHeader, "(^_^)? Commands")
    }

    func testLightPaletteDiffers() {
        XCTAssertNotEqual(Theme.light.color.primary, Theme.dark.color.primary)
        XCTAssertEqual(Theme.light.color.text, "#3D2F13")
    }

    func testSkinApplication() {
        let skin: [String: JSONValue] = [
            "ui_primary": .string("#00FF00"),
            "agent_name": .string("Custom Agent"),
            "prompt_symbol": .string("»"),
            "banner_dim": .string("#888888"),
        ]
        let themed = Theme.dark.applying(skin: skin)
        XCTAssertEqual(themed.color.primary, "#00FF00")
        XCTAssertEqual(themed.color.muted, "#888888")
        XCTAssertEqual(themed.brand.name, "Custom Agent")
        XCTAssertEqual(themed.brand.promptSymbol, "»")
        XCTAssertEqual(themed.color.accent, Theme.dark.color.accent)
    }

    private func event(_ line: String) -> GatewayEvent {
        guard let event = GatewayEvent(line: line) else {
            fatalError("bad fixture: \(line)")
        }
        return event
    }

    func testStreamingLifecycle() {
        let store = TurnStore()
        store.apply(event(#"{"type":"message.start"}"#))
        XCTAssertTrue(store.isBusy)
        store.apply(event(#"{"type":"message.delta","text":"Hel"}"#))
        store.apply(event(#"{"type":"message.delta","text":"lo"}"#))
        XCTAssertEqual(store.streamingText, "Hello")
        store.apply(event(#"{"type":"message.complete","text":"Hello there"}"#))
        XCTAssertFalse(store.isBusy)
        XCTAssertNil(store.streamingText)
        XCTAssertEqual(store.transcript.count, 1)
        XCTAssertEqual(store.transcript[0].role, "assistant")
        XCTAssertEqual(store.transcript[0].text, "Hello there")
    }

    func testToolLifecycle() {
        let store = TurnStore()
        store.apply(event(#"{"type":"tool.start","tool_id":"t1","name":"terminal","args_text":"pytest"}"#))
        XCTAssertEqual(store.tools.count, 1)
        XCTAssertTrue(store.tools[0].isRunning)
        store.apply(event(#"{"type":"tool.progress","name":"terminal","preview":"3 passed"}"#))
        XCTAssertEqual(store.tools[0].preview, "3 passed")
        store.apply(event(#"{"type":"tool.complete","tool_id":"t1","name":"terminal","summary":"done"}"#))
        XCTAssertFalse(store.tools[0].isRunning)
        XCTAssertEqual(store.tools[0].summary, "done")
    }

    func testQueueRules() {
        let store = TurnStore()
        store.enqueue("first")
        store.enqueue("second")
        store.replaceQueueItem(at: 1, with: "second edited")
        XCTAssertEqual(store.drain(), "first")
        XCTAssertEqual(store.drain(), "second edited")
        XCTAssertNil(store.drain())
        store.enqueue("x")
        store.removeQueueItem(at: 0)
        XCTAssertNil(store.drain())
    }

    func testUserSentAndStatus() {
        let store = TurnStore()
        store.userSent("hi")
        XCTAssertEqual(store.transcript.only?.role, "user")
        store.apply(event(#"{"type":"status.update","text":"thinking…"}"#))
        XCTAssertEqual(store.statusText, "thinking…")
        store.apply(event(#"{"type":"error","message":"boom"}"#))
        XCTAssertEqual(store.statusText, "error: boom")
    }
}

extension Array where Element == TurnStore.TranscriptRow {
    var only: Element? {
        count == 1 ? first : nil
    }
}
