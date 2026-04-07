import Foundation

private final class GatewaySocketDelegate: NSObject, URLSessionWebSocketDelegate {
  let didOpen: @Sendable () -> Void
  let didClose: @Sendable (String) -> Void

  init(
    didOpen: @escaping @Sendable () -> Void,
    didClose: @escaping @Sendable (String) -> Void
  ) {
    self.didOpen = didOpen
    self.didClose = didClose
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    didOpen()
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    let description = reason.flatMap { String(data: $0, encoding: .utf8) } ?? closeCode.rawValue.description
    didClose(description)
  }
}

actor GatewayClient {
  typealias EventHandler = @Sendable (GatewayEvent) -> Void
  typealias DisconnectHandler = @Sendable (String) -> Void

  private var session: URLSession?
  private var socket: URLSessionWebSocketTask?
  private var delegate: GatewaySocketDelegate?
  private var pending = [String: CheckedContinuation<Any, Error>]()
  private var connectNonce: String?
  private var connectSent = false
  private var lastSequence: Int?
  private var receiveTask: Task<Void, Never>?

  private let eventHandler: EventHandler
  private let disconnectHandler: DisconnectHandler

  init(
    eventHandler: @escaping EventHandler,
    disconnectHandler: @escaping DisconnectHandler
  ) {
    self.eventHandler = eventHandler
    self.disconnectHandler = disconnectHandler
  }

  func connect(using profile: ConnectionProfile) async throws -> GatewayHello {
    try await disconnect()

    guard let url = URL(string: profile.gatewayURL) else {
      throw GatewayDisconnectReason(message: "Invalid gateway URL")
    }

    let openContinuation = OpenSignal()
    let socketDelegate = GatewaySocketDelegate(
      didOpen: {
        Task { await openContinuation.markOpen() }
      },
      didClose: { [disconnectHandler] reason in
        disconnectHandler(reason)
      }
    )
    let configuration = URLSessionConfiguration.default
    configuration.waitsForConnectivity = true
    let session = URLSession(configuration: configuration, delegate: socketDelegate, delegateQueue: nil)
    let socket = session.webSocketTask(with: url)

    self.session = session
    self.delegate = socketDelegate
    self.socket = socket
    self.connectSent = false
    self.connectNonce = nil
    self.lastSequence = nil

    socket.resume()
    let actorSelf = self
    receiveTask = Task {
      await actorSelf.receiveLoop()
    }
    try await openContinuation.waitUntilOpen()
    try await Task.sleep(for: .milliseconds(700))

    let helloPayload = try await request(
      method: "connect",
      params: [
        "minProtocol": 3,
        "maxProtocol": 3,
        "role": "operator",
        "scopes": [
          "operator.admin",
          "operator.read",
          "operator.write",
          "operator.approvals",
          "operator.pairing",
        ],
        "caps": ["tool-events"],
        "client": [
          "id": "openclaw-control-ui",
          "version": "ios-native",
          "platform": "ios",
          "mode": "webchat",
          "instanceId": profile.clientInstanceID,
        ],
        "auth": [
          "token": profile.token,
        ],
        "userAgent": "OpenClawControl/iOS",
        "locale": Locale.current.identifier,
      ]
    )

    guard let hello = helloPayload as? [String: Any] else {
      throw GatewayDisconnectReason(message: "Missing hello response")
    }
    connectSent = true
    return parseHello(from: hello)
  }

  func disconnect() async throws {
    receiveTask?.cancel()
    receiveTask = nil
    flushPending(with: GatewayDisconnectReason(message: "Disconnected"))
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
    session?.invalidateAndCancel()
    session = nil
    delegate = nil
    connectNonce = nil
    connectSent = false
  }

  func request(method: String, params: Any? = nil) async throws -> Any {
    guard let socket, let text = serializeRequest(method: method, params: params) else {
      throw GatewayDisconnectReason(message: "WebSocket not connected")
    }

    let id = UUID().uuidString.lowercased()
    let payload = text.replacingOccurrences(of: "__REQUEST_ID__", with: id)
    let actorSelf = self

    return try await withCheckedThrowingContinuation { continuation in
      pending[id] = continuation
      socket.send(.string(payload)) { error in
        if let error {
          Task { await actorSelf.reject(id: id, error: error) }
        }
      }
    }
  }

  private func receiveLoop() async {
    guard let socket else { return }

    while !Task.isCancelled {
      do {
        let message = try await socket.receive()
        switch message {
        case .string(let text):
          try await handle(message: text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            try await handle(message: text)
          }
        @unknown default:
          break
        }
      } catch {
        disconnectHandler(error.localizedDescription)
        flushPending(with: error)
        return
      }
    }
  }

  private func handle(message: String) async throws {
    guard
      let data = message.data(using: .utf8),
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let type = json["type"] as? String
    else {
      return
    }

    if type == "event" {
      let event = json["event"] as? String ?? "unknown"
      let payload = json["payload"]
      if event == "connect.challenge",
         let payload = payload as? [String: Any],
         let nonce = payload["nonce"] as? String {
        connectNonce = nonce
      }
      if let sequence = json["seq"] as? Int {
        if let lastSequence, sequence > lastSequence + 1 {
          disconnectHandler("Gateway event gap detected. Reconnect required.")
        }
        lastSequence = sequence
      }
      eventHandler(GatewayEvent(name: event, payload: payload, sequence: json["seq"] as? Int))
      return
    }

    guard type == "res", let id = json["id"] as? String, let continuation = pending.removeValue(forKey: id) else {
      return
    }

    if (json["ok"] as? Bool) == true {
      continuation.resume(returning: json["payload"] ?? [:])
      return
    }

    let errorPayload = (json["error"] as? [String: Any])?["message"] as? String ?? "Request failed"
    continuation.resume(throwing: GatewayDisconnectReason(message: errorPayload))
  }

  private func reject(id: String, error: Error) {
    guard let continuation = pending.removeValue(forKey: id) else {
      return
    }
    continuation.resume(throwing: error)
  }

  private func flushPending(with error: Error) {
    let entries = pending
    pending.removeAll()
    for (_, continuation) in entries {
      continuation.resume(throwing: error)
    }
  }

  private func serializeRequest(method: String, params: Any?) -> String? {
    var frame: [String: Any] = [
      "type": "req",
      "id": "__REQUEST_ID__",
      "method": method,
    ]
    if let params {
      frame["params"] = params
    }

    guard JSONSerialization.isValidJSONObject(frame),
      let data = try? JSONSerialization.data(withJSONObject: frame),
      let text = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return text
  }

  private func parseHello(from payload: [String: Any]) -> GatewayHello {
    let server = payload["server"] as? [String: Any]
    let auth = payload["auth"] as? [String: Any]
    let policy = payload["policy"] as? [String: Any]
    return GatewayHello(
      protocolVersion: payload["protocol"] as? Int ?? 3,
      serverVersion: server?["version"] as? String ?? "unknown",
      connectionID: server?["connId"] as? String,
      tickIntervalMS: policy?["tickIntervalMs"] as? Int,
      authRole: auth?["role"] as? String,
      authScopes: auth?["scopes"] as? [String] ?? [],
      snapshot: payload["snapshot"] as? [String: Any] ?? [:]
    )
  }
}

private actor OpenSignal {
  private var isOpen = false
  private var waiters = [CheckedContinuation<Void, Error>]()

  func markOpen() {
    isOpen = true
    let continuations = waiters
    waiters.removeAll()
    continuations.forEach { $0.resume() }
  }

  func waitUntilOpen() async throws {
    if isOpen {
      return
    }
    try await withCheckedThrowingContinuation { continuation in
      waiters.append(continuation)
    }
  }
}
