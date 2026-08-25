import Foundation
import SwiftUI

public enum MarkdownRenderer {
    public static func render(_ markdown: String) -> AttributedString {
        var blocks: [AttributedString] = []
        var inFence = false
        var fenceBuffer: [String] = []

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inFence {
                    blocks.append(codeBlock(fenceBuffer))
                    fenceBuffer = []
                }
                inFence.toggle()
                continue
            }
            if inFence {
                fenceBuffer.append(rawLine)
                continue
            }
            if line.isEmpty {
                continue
            }
            if line.hasPrefix("#") {
                let heading = line.drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                let level = line.prefix(while: { $0 == "#" }).count
                blocks.append(inline(level <= 2 ? "**\(heading)**" : heading))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(inline("•  " + line.dropFirst(2)))
            } else if line.hasPrefix("> ") {
                blocks.append(inline("| " + line.dropFirst(2)))
            } else {
                blocks.append(inline(line))
            }
        }
        if inFence, !fenceBuffer.isEmpty {
            blocks.append(codeBlock(fenceBuffer))
        }
        return blocks.reduce(into: AttributedString()) { result, block in
            result += block + AttributedString("\n")
        }
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(text, options: options)) ?? AttributedString(text)
    }

    static func codeBlock(_ lines: [String]) -> AttributedString {
        var result = AttributedString(lines.joined(separator: "\n"))
        result[AttributeScopes.SwiftUI.Attributes.FontAttribute.self] = .system(.body, design: .monospaced)
        return result
    }
}
