import XCTest
@testable import HermesKit

final class MarkdownTests: XCTestCase {
    func testInlineStyles() {
        let result = MarkdownRenderer.render("This is **bold** and *italic* and `code`.")
        let text = String(result.characters)
        XCTAssertEqual(text, "This is bold and italic and code.\n")

        let intents = result.runs.compactMap { $0.inlinePresentationIntent }
        XCTAssertTrue(intents.contains(.stronglyEmphasized))
        XCTAssertTrue(intents.contains(.emphasized))
        XCTAssertTrue(intents.contains(.code))
    }

    func testLinks() {
        let result = MarkdownRenderer.render("See [docs](https://example.com) for more.")
        XCTAssertTrue(String(result.characters).contains("docs"))
        XCTAssertTrue(result.runs.contains { $0.link != nil })
    }

    func testHeadingsBecomeBold() {
        let result = MarkdownRenderer.render("# Title\nbody")
        XCTAssertEqual(String(result.characters), "Title\nbody\n")
        XCTAssertTrue(result.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    func testBullets() {
        let result = MarkdownRenderer.render("- one\n- two")
        XCTAssertEqual(String(result.characters), "•  one\n•  two\n")
    }

    func testCodeFence() {
        let result = MarkdownRenderer.render("```\nlet x = 1\n```")
        XCTAssertTrue(String(result.characters).contains("let x = 1"))
    }

    func testBlockquote() {
        let result = MarkdownRenderer.render("> quoted")
        XCTAssertEqual(String(result.characters), "| quoted\n")
    }
}
