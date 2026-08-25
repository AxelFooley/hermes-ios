# Hermes iOS

A native SwiftUI client for [Hermes Agent](https://github.com/NousResearch/hermes-agent) — the Hermes TUI, rebuilt for iPhone and iPad.

The Hermes TUI (`hermes --tui`) is a React + Ink terminal UI that speaks newline-delimited JSON-RPC to a Python gateway. That protocol is the app's contract: Hermes iOS is a **protocol-native client** — no embedded terminal, no WebView — that renders the same event surface (`message.delta`, `tool.progress`, `approval.request`, `subagent.*`, …) as native iOS UI in the TUI's visual identity: navy surfaces, gold accents, cream text, kaomoji busy faces.

> Community project. Not affiliated with or endorsed by Nous Research.

## Connects to

| Backend | How |
|---|---|
| `hermes serve` | WebSocket to the tui_gateway JSON-RPC API (same as Hermes Desktop) |
| `hermes --tui dashboard` | `/api/ws` with the session token auto-discovered from the dashboard HTML |

Both are configured as connection profiles in **Settings**; a capability probe ("Test Connection") validates reachability before first use. Use Tailscale/LAN or an SSH tunnel — never expose a Hermes gateway to the public internet.

## Layout

```
App/          SwiftUI app (Chat · Sessions · Power · Files · Settings)
HermesKit/    Swift package: protocol models, gateway client, theme, markdown, turn logic
docs/spec/    Design spec (full research + architecture)
docs/mockups/ Visual mockup (open in a browser — exact TUI palette)
```

## Development

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen
open Hermes.xcodeproj
```

HermesKit tests run standalone:

```bash
cd HermesKit && swift test
```

## CI

Every push and PR runs:

| Check | Tool |
|---|---|
| Unit tests | `swift test` (HermesKit) on macOS |
| App build | XcodeGen + `xcodebuild` for the iOS simulator |
| Code quality | SwiftLint (`--strict`) |
| Security analysis | CodeQL (Swift) |
| Secrets leak detection | Gitleaks |
| Dependency review | `dependency-review-action` on PRs |

## Roadmap

Full TUI parity ships in three phases (see `docs/spec`):

1. **Core chat parity** — connections, banner card, streaming transcript, tool cards, approvals/clarify/sudo, queue + busy rules, sessions, model picker, slash autocomplete *(this repository's initial milestone)*
2. **Power panels** — usage, agents tree, skills hub, background tasks + Live Activities, billing, voice
3. **Full parity** — workspace files browser, skin live-preview, widgets
