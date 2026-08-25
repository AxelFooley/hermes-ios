import Foundation

public struct ThemeColors: Sendable, Equatable {
    public var primary: String
    public var accent: String
    public var border: String
    public var text: String
    public var muted: String
    public var label: String
    public var ok: String
    public var error: String
    public var warn: String
    public var tool: String
    public var thinking: String
    public var prompt: String
    public var statusBg: String
    public var statusFg: String
    public var statusGood: String
    public var statusWarn: String
    public var statusBad: String
    public var statusCritical: String
    public var selectionBg: String
    public var shellDollar: String
    public var diffAdded: String
    public var diffRemoved: String
}

public struct ThemeBrand: Sendable, Equatable {
    public var name: String
    public var icon: String
    public var promptSymbol: String
    public var welcome: String
    public var goodbye: String
    public var toolMarker: String
    public var helpHeader: String
}

public struct Theme: Sendable, Equatable {
    public var color: ThemeColors
    public var brand: ThemeBrand

    public static let dark = Theme(
        color: ThemeColors(
            primary: "#FFD700",
            accent: "#FFBF00",
            border: "#CD7F32",
            text: "#FFF8DC",
            muted: "#CC9B1F",
            label: "#DAA520",
            ok: "#4caf50",
            error: "#ef5350",
            warn: "#ffa726",
            tool: "#FFBF00",
            thinking: "#CC9B1F",
            prompt: "#FFF8DC",
            statusBg: "#1a1a2e",
            statusFg: "#C0C0C0",
            statusGood: "#8FBC8F",
            statusWarn: "#FFD700",
            statusBad: "#FF8C00",
            statusCritical: "#FF6B6B",
            selectionBg: "#3a3a55",
            shellDollar: "#4dabf7",
            diffAdded: "rgb(220,255,220)",
            diffRemoved: "rgb(255,220,220)"
        ),
        brand: ThemeBrand(
            name: "Hermes Agent",
            icon: "⚕",
            promptSymbol: "❯",
            welcome: "Type your message or /help for commands.",
            goodbye: "Goodbye! ⚕",
            toolMarker: "┊",
            helpHeader: "(^_^)? Commands"
        )
    )

    public static let light = Theme(
        color: ThemeColors(
            primary: "#867000",
            accent: "#956E00",
            border: "#A56628",
            text: "#3D2F13",
            muted: "#946C08",
            label: "#8E6B13",
            ok: "#367E39",
            error: "#C14240",
            warn: "#956115",
            tool: "#956E00",
            thinking: "#946C08",
            prompt: "#2B2014",
            statusBg: "#F5F5F5",
            statusFg: "#6F6F6F",
            statusGood: "#5C7A5C",
            statusWarn: "#867000",
            statusBad: "#A65A00",
            statusCritical: "#B94D4D",
            selectionBg: "#D4E4F7",
            shellDollar: "#377BB3",
            diffAdded: "rgb(200,240,200)",
            diffRemoved: "rgb(240,200,200)"
        ),
        brand: Theme.dark.brand
    )

    public func applying(skin: [String: JSONValue]) -> Theme {
        var theme = self
        let stringKeys: [(String, WritableKeyPath<ThemeColors, String>)] = [
            ("ui_primary", \.primary),
            ("banner_title", \.primary),
            ("ui_accent", \.accent),
            ("banner_accent", \.accent),
            ("ui_border", \.border),
            ("banner_border", \.border),
            ("ui_text", \.text),
            ("banner_text", \.text),
            ("banner_dim", \.muted),
            ("ui_label", \.label),
            ("ui_ok", \.ok),
            ("ui_error", \.error),
            ("ui_warn", \.warn),
            ("ui_tool", \.tool),
            ("ui_thinking", \.thinking),
            ("prompt", \.prompt),
            ("status_bar_bg", \.statusBg),
            ("status_bar_text", \.statusFg),
            ("status_bar_good", \.statusGood),
            ("status_bar_warn", \.statusWarn),
            ("status_bar_bad", \.statusBad),
            ("status_bar_critical", \.statusCritical),
            ("selection_bg", \.selectionBg),
            ("shell_dollar", \.shellDollar),
            ("diff_added", \.diffAdded),
            ("diff_removed", \.diffRemoved),
        ]
        for (key, path) in stringKeys {
            if let value = skin[key]?.stringValue {
                theme.color[keyPath: path] = value
            }
        }
        var brand = theme.brand
        if let value = skin["agent_name"]?.stringValue { brand.name = value }
        if let value = skin["welcome"]?.stringValue { brand.welcome = value }
        if let value = skin["goodbye"]?.stringValue { brand.goodbye = value }
        if let value = skin["prompt_symbol"]?.stringValue, !value.trimmingCharacters(in: .whitespaces).isEmpty {
            brand.promptSymbol = value
        }
        if let value = skin["tool_prefix"]?.stringValue, !value.isEmpty { brand.toolMarker = value }
        if let value = skin["help_header"]?.stringValue { brand.helpHeader = value }
        theme.brand = brand
        return theme
    }
}
