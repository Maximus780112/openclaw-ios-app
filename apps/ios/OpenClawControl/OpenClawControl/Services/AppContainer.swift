import Foundation

struct AppContainer {
  let keychain = KeychainService(service: "ai.openclaw.control")
  let cacheStore = LocalCacheStore()
  let networkMonitor = NetworkMonitor()

  @MainActor
  func makeConfigurationStore() -> SecureConfigurationStore {
    SecureConfigurationStore(keychain: keychain, bundle: .main)
  }
}

