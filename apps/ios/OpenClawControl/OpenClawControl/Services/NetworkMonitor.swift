import Foundation
import Network

final class NetworkMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "ai.openclaw.control.network")

  var onPathChange: (@Sendable (Bool) -> Void)?

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      self?.onPathChange?(path.status == .satisfied)
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}

