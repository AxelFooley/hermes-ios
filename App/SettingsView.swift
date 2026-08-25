import SwiftUI
import HermesKit

struct SettingsView: View {
    @Environment(ProfileStore.self) private var profiles

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection profiles") {
                    ForEach(profiles.profiles) { profile in
                        NavigationLink {
                            ProfileEditorView(profile: profile)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                    Text("\(profile.mode.label) · \(profile.url)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if profiles.active?.id == profile.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    NavigationLink("Add profile") {
                        ProfileEditorView(profile: nil)
                    }
                }
                Section("Appearance") {
                    AppearancePicker()
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Protocol", value: "tui_gateway JSON-RPC")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct AppearancePicker: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Picker("Theme", selection: $appearance) {
            Text("System").tag("system")
            Text("Dark").tag("dark")
            Text("Light").tag("light")
        }
    }
}

struct ProfileEditorView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    let existing: ConnectionProfile?
    @State private var name: String
    @State private var url: String
    @State private var mode: ConnectionMode
    @State private var token: String
    @State private var testResult: String?
    @State private var testing = false

    init(profile: ConnectionProfile?) {
        existing = profile
        _name = State(initialValue: profile?.name ?? "")
        _url = State(initialValue: profile?.url ?? "http://127.0.0.1:9119")
        _mode = State(initialValue: profile?.mode ?? .serve)
        _token = State(initialValue: "")
    }

    var body: some View {
        Form {
            Section("Server") {
                TextField("Name", text: $name)
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Mode", selection: $mode) {
                    ForEach(ConnectionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                if mode == .dashboard {
                    SecureField("Session token (auto-discovered if blank)", text: $token)
                }
            }
            Section {
                Button {
                    testConnection()
                } label: {
                    if testing {
                        ProgressView()
                    } else {
                        Text("Test Connection")
                    }
                }
                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.hasPrefix("OK") ? .green : .red)
                }
            }
            Section {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(name.isEmpty || url.isEmpty)
                if let existing {
                    Button("Delete", role: .destructive) {
                        profiles.remove(existing)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? "Add profile" : "Edit profile")
        .onAppear {
            if let existing, token.isEmpty {
                token = KeychainStore.load(account: "profile.\(existing.id.uuidString)") ?? ""
            }
        }
    }

    private func save() {
        var profile = existing ?? ConnectionProfile(name: name, url: url, mode: mode)
        profile.name = name
        profile.url = url
        profile.mode = mode
        KeychainStore.save(token, account: "profile.\(profile.id.uuidString)")
        profiles.save(profile)
    }

    private func testConnection() {
        testing = true
        testResult = nil
        var profile = existing ?? ConnectionProfile(name: name, url: url, mode: mode)
        profile.url = url
        profile.mode = mode
        Task {
            do {
                let connection = try await ChatModel.makeConnectionFactory(profile: profile)()
                try await connection.connect()
                await connection.close()
                testResult = "OK — reachable"
            } catch {
                testResult = "FAIL — \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
