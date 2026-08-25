import SwiftUI
import HermesKit

struct RootView: View {
    @State private var chatModel = ChatModel()
    @State private var profiles = ProfileStore()
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "terminal") }
            SessionsView()
                .tabItem { Label("Sessions", systemImage: "list.bullet") }
            PowerView()
                .tabItem { Label("Power", systemImage: "gauge.with.needle") }
            FilesView()
                .tabItem { Label("Files", systemImage: "folder") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(HermesPalette.standard.primary)
        .environment(chatModel)
        .environment(profiles)
        .preferredColorScheme(colorScheme)
        .onAppear {
            if let profile = profiles.active {
                chatModel.connect(profile: profile)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}
