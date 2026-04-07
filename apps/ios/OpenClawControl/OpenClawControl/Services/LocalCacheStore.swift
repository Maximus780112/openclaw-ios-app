import Foundation

actor LocalCacheStore {
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private var cachedState = CachedAppState.empty

  func load() -> CachedAppState {
    if let inMemory = tryLoadFromDisk() {
      cachedState = inMemory
    }
    return cachedState
  }

  func save(_ state: CachedAppState) {
    cachedState = state
    guard let data = try? encoder.encode(state) else {
      return
    }

    let url = storageURL()
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    try? data.write(to: url, options: [.atomic])
  }

  private func tryLoadFromDisk() -> CachedAppState? {
    let url = storageURL()
    guard let data = try? Data(contentsOf: url) else {
      return nil
    }
    return try? decoder.decode(CachedAppState.self, from: data)
  }

  private func storageURL() -> URL {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
      URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return base
      .appendingPathComponent("OpenClawControl", isDirectory: true)
      .appendingPathComponent("cache.json", isDirectory: false)
  }
}
