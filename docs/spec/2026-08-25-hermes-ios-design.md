# Hermes iOS — Native SwiftUI Client Design

**Status:** Draft for review
**Date:** 2026-08-25
**Approach:** A — Protocol-native client (user-selected: official Hermes TUI look, both backends, full parity, native SwiftUI, iPhone + iPad)

## 0. Goal

Bring the Hermes Agent TUI (`hermes --tui`, React + Ink) to iPhone and iPad as a first-class native app. The terminal is the wrong surface for touch; the app therefore re-skins the TUI's *information architecture* into native iOS UI while speaking the exact same protocol the TUI speaks. Same agent, same sessions, same slash commands — a native surface instead of a character grid.

Non-goals: embedding a terminal emulator (that is what already fails on mobile); becoming a second agent runtime; replacing hermes-webui.

## 1. Background (research summary)

Hermes Agent = Python runtime on a user-owned server. The TUI is a TypeScript React+Ink front-end that spawns `python -m tui_gateway.entry` and exchanges newline-delimited JSON-RPC over stdio. Python owns sessions, tools, model calls; TypeScript owns the screen.

Key protocol facts (from `ui-tui/src/gatewayClient.ts`, `gatewayTypes.ts`, README):

- **Transport:** JSON-RPC requests/responses + server-push events, one JSON object per line (stdio in the TUI; WebSocket `/api/ws` when the dashboard embeds it via `HERMES_TUI_GATEWAY_URL`; `hermes serve` serves the same tui_gateway API over WebSocket for the desktop app).
- **Event surface:** `gateway.ready {skin}`, `skin.changed`, `session.info`, `message.start/delta/complete`, `thinking.delta`, `reasoning.delta/available`, `status.update`, `notification.show/clear`, `tool.start/generating/progress/complete`, `clarify.request`, `approval.request`, `sudo.request/expire`, `secret.request/expire`, `background.complete`, `billing.step_up.verification`, `review.summary`, `browser.progress`, `voice.status/transcript`, `subagent.spawn_requested/start/thinking/tool/progress/complete`, `error`.
- **RPC used by the client:** `slash.exec`, `command.dispatch`, `config.get`, `complete.slash`, `complete.path`, session create/resume/activate/close, model list/select, shell exec (`!cmd`), plus prompt *responses* to approval/clarify/sudo/secret request ids.
- **Prompt flows are stateful UI branches**, not screens: approval (once/session/always/deny; quick keys o/s/a/d), clarify (numbered choices or "Other" free text), sudo/secret (masked entry, Ctrl+C cancels with empty response).
- **Busy-input rules:** plain text while busy → queue (auto-drains after each response; editable; edited item promotes to front); slash commands and `!cmd` never queue.
- **Details modes per section:** thinking / tools / subagents / activity each have hidden | collapsed | expanded. Defaults: thinking expanded, tools expanded, subagents collapsed, activity hidden.

### Visual identity (from `ui-tui/src/theme.ts`)

Dark seeds (default): bg `#101014`, surface `#1a1a2e`, activeRow `#333355`, selection `#3a3a55`, primary `#FFD700` (gold), accent `#FFBF00` (amber), border `#CD7F32` (bronze), text & prompt `#FFF8DC` (cream), ok `#4caf50`, error `#ef5350`, warn `#ffa726`, statusGood `#8FBC8F`, statusBad `#FF8C00`, statusCritical `#FF6B6B`, shellDollar `#4dabf7`. Derived muted ≈ `#CC9B1F`, label ≈ `#DAA520`, statusFg ≈ `#C0C0C0`.

Light seeds exist and are selected by background detection; skins override seeds and every secondary tone derives by color-mix against the skin's own canvas.

Branding: icon `⚕`, prompt `❯`, tool marker `┊`, help header `(^_^)? Commands`, welcome "Type your message or /help for commands.", goodbye "Goodbye! ⚕". Busy indicator rotates kawaii faces every 2.5 s (styles: kaomoji | emoji | unicode | ascii).

Status line contents: state text (starting agent… / ready / thinking… / running… / interrupted / forging session… / resuming…), cwd with git branch, per-prompt elapsed `⏱ 12s/3m 45s` (frozen `⏲` after completion), `🗜️ N` compressions, `▶ N` background tasks, `⚠ YOLO` badge, session title badge at right edge.

Banner: collapsible sections with ▸/▾ chevrons — Tools (open by default), Skills, System Prompt, MCP Servers (collapsed).

Overlays as modal panels: /help (categorized), /sessions live switcher, /model picker grouped by provider with cost hints, /skin live-preview, /usage token/cost/context panel, /agents observability tree with kill/pause and per-branch cost/token/file rollups.

## 2. Architecture

```
┌──────────────────────────────────────────────────┐
│ SwiftUI Views (iOS 17+, Observation)             │
│ Chat · Sessions · Power · Files · Settings       │
├──────────────────────────────────────────────────┤
│ @Observable stores                                │
│ SessionStore TurnStore QueueStore ApprovalStore   │
│ SubagentStore UsageStore SkinStore NotifRouter    │
├──────────────────────────────────────────────────┤
│ GatewayClient (actor)                             │
│  - request/response correlation (JSON-RPC ids)    │
│  - event fan-out via AsyncStream per store        │
│  - reconnect ladder + resume-on-reconnect         │
├──────────────────────────────────────────────────┤
│ GatewayConnection (protocol)                      │
│  ├─ ServeConnection      ws://host → hermes serve │
│  └─ DashboardConnection ws://host/api/ws + ticket │
├──────────────────────────────────────────────────┤
│ HermesKit (Swift package)                         │
│  Codable event/RPC models · Markdown+LaTeX render │
│  Skin→Token mapper · fixtures + tests             │
└──────────────────────────────────────────────────┘
```

- **GatewayConnection protocol** hides backend differences behind one interface: connect/disconnect, send(request), events AsyncStream, capabilities set (e.g. dashboard exposes token discovery from HTML like KrydenAI/hermes-mobile; serve accepts direct URL + optional token). A Settings "Test connection" runs a capability probe.
- **GatewayClient actor** owns one active connection, correlates RPC ids, decodes events into typed values, and exposes typed streams. Mirrors TUI crash-recovery semantics: auto-respawn/reconnect budget of 3 attempts / 60 s, then user-visible reconnect banner with manual retry.
- **TurnStore** ports `turnController`/`turnStore`: buffers streaming deltas, tracks tool states, reasoning text, subagents, todos, activity trail; publishes immutable turn snapshots that views render.
- **Markdown engine**: Swift AttributedString renderer covering the TUI subset — headings, lists, block quotes, tables, fenced code (syntax tokens mapped to theme), diff coloring, inline code, emphasis, links, bare URLs, LaTeX→Unicode inline math (fallback: literal TeX in code span). Streaming variant re-renders the open assistant block incrementally (batch deltas on a ~30–60 ms cadence like `config/timing.ts`).
- **SkinStore** receives `gateway.ready {skin}` / `skin.changed` and maps skin seeds → SwiftUI Theme tokens using the same derivation ladder (muted/label/surface/activeRow/border mixes) ported from `deriveTones`; contrast floors applied against the resolved background.

## 3. Design system ("TUI look, native feel")

Tokens mirror `ThemeColors` 1:1 (names kept): `primary, accent, border, text, muted, label, completionBg, completionCurrentBg, ok/error/warn, tool, thinking, syntax*, prompt, statusBg/Fg/Good/Warn/Bad/Critical, selectionBg, diffAdded/Removed(+word), shellDollar`. Default dark palette = section 1 hexes; light palette = LIGHT_SEEDS equivalents; follows system appearance unless user pins dark/light.

Typography: SF Pro for prose; SF Mono (user-swappable) for code, banner art, status capsule, transcript role labels. Monospace is load-bearing for the TUI identity.

Signature elements translated natively:

| TUI element | iOS translation |
|---|---|
| ASCII banner + collapsible sections | Session header card: ⚕ logo, title badge, Tools/Skills/System Prompt/MCP DisclosureGroups (Tools open) |
| Static transcript | Scrollable transcript; role labels colored (roles.ts mapping), assistant markdown |
| Live streaming assistant row | Auto-growing assistant block with kaomoji spinner while streaming |
| Thinking/tools/subagents/activity lane | Inline accordions honoring hidden/collapsed/expanded defaults & overrides |
| Status line | Compact status capsule pinned above composer (state, cwd⎇branch, ⏱/⏲ elapsed, 🗜️, ▶ N, ⚠ YOLO, tap → detail popover) |
| Queue preview | Editable chips row above composer |
| Floating slash-completion panel | Autocomplete strip above keyboard ("/" triggers; descriptions shown; Tab-equivalent = tap or return) |
| Modal overlays (/help, /model, /sessions, /usage, /agents, /skin) | Sheets with grabber; /skin previews live |
| Approval o/s/a/d quick keys | Button row: Once · Session · Always · Deny (+ swipe Deny) |
| Clarify numbered choices | List with number badges + "Other…" free-text |
| Sudo/secret masked input | Alert-style SecureField sheet |
| Kaomoji busy faces | Animated Text swapping faces every 2.5 s (style configurable) |

## 4. Screens & navigation

iPhone: UITabBarController-style tab bar — **Chat · Sessions · Power · Files · Settings**. iPad / landscape: NavigationSplitView — sidebar (Sessions/Power sections), chat detail; Files and Power become columns. All five areas reachable without losing chat state (chat stays mounted, PTY-free so backgrounding is safe).

1. **Chat** — banner card, transcript, streaming blocks, tool cards, queue chips, composer (❯ prefix, attachment 📎 for images/files mirroring paste-image fallback, mic button), status capsule. Composer toolbar: newline key, Stop (when busy → interrupt), Steer, History ↑↓.
2. **Sessions** — live sessions (source tag "live"), saved transcripts from state.db via gateway session.list, search, swipe: resume / close / rename(/title); "+ New" row (optional per-session model choice before dispatch, like switcher Tab behavior).
3. **Power** — hub list: Model picker, Usage panel, Agents tree (live subagent tree, kill/pause, rollups, /replay history ring last 10 fan-outs), Skills hub, Background tasks, Billing & credits (step-up verification opens verification_url SFSafariViewController with user_code copy).
4. **Files** — workspace browser when backend capability present: browse, preview (code/markdown/image), upload via share sheet / Files picker, download/share, git branch badge. Hidden with explanation when unsupported.
5. **Settings** — Server profiles (multiple; URL, auth mode: none/token/user-pass/dashboard-ticket; Test Connection), Appearance (theme mode, skin, indicator style, details-mode editor per section), Notifications (turn complete, approvals waiting), Voice, About.

Slash commands remain the power surface: "/" opens autocomplete; unrecognized commands fall through `slash.exec` → `command.dispatch` exactly like the TUI. Long-press composer ❯ = command palette (fuzzy search over registry, mirrors Ctrl+K conventions).

## 5. Interaction model

- Keyboard: Return sends; Shift⏎ equivalent via accessory "⏎+" newline key; external hardware keyboards map TUI chords where iOS allows (Esc=interrupt editing, ⌘K palette, ⌘N new session, ⌥⏎ newline).
- Busy behavior identical to TUI: plain text queues; slash/! run immediately; empty-Enter twice drains/interrupts → rendered as explicit chip actions plus gesture. Composer toolbar exposes the three busy-input modes explicitly: **Queue** (default), **Steer** (send mid-turn to redirect the current run, `/steer` semantics), **Stop** (interrupt).
- Approvals block input (modal sheet) like blocking prompts suspend hotkeys; expiry events clear stale sheets.
- Streaming UX: stick-to-bottom autoscroll that releases on user scroll-up with a "jump to latest ↓" pill; long tool progress shows live preview line.
- Voice: push-to-talk; Speech framework transcription streams into `voice.transcript`-shaped flow; final text lands in composer (send confirmation on by default).
- Background: turn continues server-side (agent lives on the server). Local notification on turn complete/approval-needed; Live Activity shows current status capsule state and elapsed timer.

## 6. Persistence, error handling, security

- Keychain: auth tokens, passwords. AppStorage: profiles' non-secret fields, appearance, details modes.
- Offline: last N transcripts cached read-only (SQLite, same shape as state.db rows received); sending requires connectivity — composer offers "queue on reconnect" draft retention.
- Reconnect ladder: exponential backoff (1→2→4→8 s) inside the 3-attempts/60 s budget; then banner "Chat is reconnecting / Reconnect now" (dashboard parity wording). `error` events toast; `gateway.protocol_error` surfaces diagnostic view with raw frames for bug reports.
- Trust boundary: TLS enforced except user-flagged `--insecure` LAN/Tailscale http; host allowlist per profile; secrets never logged (mirror parentLog discipline).

## 7. Testing

- HermesKit unit tests against recorded golden JSON-RPC streams captured from real `hermes serve` sessions (event decode → store snapshots).
- TurnStore reducer tests: streaming, tools, interrupts, queue promote/edit rules.
- Markdown/LaTeX snapshot tests (dark/light, skin overrides).
- Mock gateway: local URLProtocol/WebSocket fixture server replays recorded streams; UI smoke test: connect → send → stream → approval sheet flow.

## 8. Phased roadmap (full parity lands across three shippable phases)

- **Phase 1 — Core chat parity:** both connections + profiles, banner card, transcript/streaming/tool cards with details modes, approvals/clarify/sudo/secret sheets, queue chips + busy rules, status capsule, Sessions tab, Model picker, slash autocomplete + palette, Settings/Appearance, notifications (local).
- **Phase 2 — Power panels:** Usage, Agents tree + replay, Skills hub, Background tasks + Live Activity, Billing/credits handoff, voice mode, iPad split refinements.
- **Phase 3 — Full parity polish:** Workspace Files browser, /skin live-preview marketplace, widgets (quick-launch prompts), optional raw-terminal escape-hatch tab (SwiftTerm) if ever wanted.

## 9. Open items (decisions deferred to implementation planning)

- Exact minimum iOS version (17 proposed for Observation; confirm no older-device need).
- Whether dashboard REST endpoints beyond /api/ws are needed for Files on the dashboard backend (probe during Phase 1 spike).
