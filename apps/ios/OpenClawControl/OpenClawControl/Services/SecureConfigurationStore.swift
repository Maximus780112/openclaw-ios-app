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
       let data = existing,
       let profile = try? decoder.decode(ConnectionProfile.self, from: data) {
      return repaired(profile)
    }

    guard let bootstrap = bootstrapProfile() else {
      return nil
    }
    saveProfile(bootstrap)
    return bootstrap
  }

  func saveProfile(_ profile: ConnectionProfile) {
    let repairedProfile = repaired(profile)
    guard let data = try? encoder.encode(repairedProfile) else {
      return
    }
    try? keychain.save(data, account: Keys.profile)
  }

  func clearProfile() {
    keychain.delete(account: Keys.profile)
  }

  private func repaired(_ profile: ConnectionProfile) -> ConnectionProfile {
    var next = profile
    if next.deviceID.isEmpty {
      next.deviceID = UUID().uuidString.lowercased()
    }
    if next.clientInstanceID.isEmpty {
      next.clientInstanceID = UUID().uuidString.lowercased()
    }
    if next.currentSessionKey.isEmpty {
      next.currentSessionKey = "main"
    }
    if next.displayName.isEmpty {
      next.displayName = "OpenClaw Gateway"
    }
    return next
  }

  private func bootstrapProfile() -> ConnectionProfile? {
    guard
      let url = bundle.object(forInfoDictionaryKey: "OpenClawBootstrapGatewayURL") as? String,
      let token = bundle.object(forInfoDictionaryKey: "OpenClawBootstrapGatewayToken") as? String
    else {
      return nil
    }

    let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedURL.isEmpty, !trimmedToken.isEmpty else {
      return nil
    }

    let displayName =
      (bundle.object(forInfoDictionaryKey: "OpenClawBootstrapDisplayName") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return ConnectionProfile.bootstrapDefaults(
      gatewayURL: trimmedURL,
      token: trimmedToken,
      displayName: displayName?.isEmpty == false ? displayName! : "OpenClaw Gateway"
    )
  }
}

