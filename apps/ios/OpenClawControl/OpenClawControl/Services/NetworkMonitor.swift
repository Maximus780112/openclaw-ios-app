import Foundation
import Network

final class NetworkMonitor: @unchecked Sendable {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "ai.openclaw.control.network")

  var onPathChange: ((Bool) -> Void)?

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
