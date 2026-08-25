import Foundation
import HermesKit

enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case serve
    case dashboard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .serve: return "hermes serve"
        case .dashboard: return "Dashboard"
        }
    }
}

struct ConnectionProfile: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var url: String
    var mode: ConnectionMode
}

@Observable
final class ProfileStore {
    static private let storageKey = "hermes.profiles.v1"
    static private let activeKey = "hermes.activeProfile"

    var profiles: [ConnectionProfile] = []
    var activeID: UUID?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            profiles = decoded
        }
        if let saved = UserDefaults.standard.string(forKey: Self.activeKey) {
            activeID = UUID(uuidString: saved)
        }
    }

    var active: ConnectionProfile? {
        profiles.first { $0.id == activeID } ?? profiles.first
    }

    func save(_ profile: ConnectionProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
            if activeID == nil { activeID = profile.id }
        }
        persist()
    }

    func remove(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeID == profile.id {
            activeID = profiles.first?.id
        }
        persist()
    }

    func activate(_ profile: ConnectionProfile) {
        activeID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Self.activeKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

enum KeychainStore {
    static func save(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ai.hermes.ios",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
        ]
        SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ai.hermes.ios",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
