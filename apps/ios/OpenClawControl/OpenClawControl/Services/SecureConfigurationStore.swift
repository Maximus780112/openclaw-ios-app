import Foundation

@MainActor
final class SecureConfigurationStore {
    private enum Keys {
        static let profile = "connection.profile"
    }

    private let keychain: KeychainService
    private let bundle: Bundle
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(keychain: KeychainService, bundle: Bundle) {
        self.keychain = keychain
        self.bundle = bundle
    }

    func loadProfile() -> ConnectionProfile? {
        if let existing = try? keychain.load(account: Keys.profile),
           let profile = try? decoder.decode(ConnectionProfile.self, from: existing) {
            return repaired(profile)
        }
        return nil
    }

    func saveProfile(_ profile: ConnectionProfile) throws {
        let data = try encoder.encode(profile)
        try keychain.save(data, account: Keys.profile)
    }

    func clearProfile() throws {
        try keychain.delete(account: Keys.profile)
    }

    private func repaired(_ profile: ConnectionProfile) -> ConnectionProfile {
        profile
    }
}
