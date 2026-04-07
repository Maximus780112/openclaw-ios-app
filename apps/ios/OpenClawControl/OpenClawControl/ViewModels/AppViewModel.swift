import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
  @Published var activeRoute: ControlRoute = .chat
  @Published var connectionPhase: ConnectionPhase = .disconnected
  @Published var connectionDetail = "Waiting for configuration"
  @Published var profile = ConnectionProfile.bootstrapDefaults(
    gatewayURL: "",
    token: "",
    displayName: "OpenClaw Gateway"
  )
  @Published var draft = ""
  @Published var messages: [ChatMessage] = []
  @Published var sessions: [SessionSummary] = []
  @Published var usage = UsageSummary(
    totalRequests: 0,
    totalInputTokens: 0,
    totalOutputTokens: 0,
    totalCostUSD: 0,
    points: []
  )
  @Published var agents: [AgentSummary] = []
  @Published var server = ServerSummary(
    version: "unknown",
    connectionID: nil,
    uptimeSeconds: 0,
    heartbeatSeconds: 0,
    isHealthy: false,
    authMode: nil,
    defaultAgentID: nil,
    sessionCount: 0
  )
  @Published var drawerPresented = false
  @Published var chatSearchText = ""
  @Published var lastError: String?

  let quickActions = QuickAction.defaults

  private let cacheStore: LocalCacheStore
  private let configurationStore: SecureConfigurationStore
  private let networkMonitor: NetworkMonitor
  private var cachedMessagesBySession = [String: [ChatMessage]]()
  private var reconnectAttempt = 0
  private var reconnectTask: Task<Void, Never>?
  private lazy var gatewayClient = GatewayClient(
    eventHandler: { [weak self] event in
      Task { @MainActor [weak self] in
        self?.handleGatewayEvent(event)
      }
    },
    disconnectHandler: { [weak self] reason in
      Task { @MainActor [weak self] in
        self?.handleDisconnect(reason: reason)
      }
    }
  )

  init(container: AppContainer) {
    self.cacheStore = container.cacheStore
    self.configurationStore = container.makeConfigurationStore()
    self.networkMonitor = container.networkMonitor
    networkMonitor.onPathChange = { [weak self] isReachable in
      Task { @MainActor [weak self] in
        self?.handleNetwork(isReachable: isReachable)
      }
    }
  }

  func start() async {
    let cached = await cacheStore.load()
    activeRoute = cached.activeRoute
    if let cachedProfile = cached.profile {
      profile = cachedProfile
    } else if let secureProfile = configurationStore.loadProfile() {
      profile = secureProfile
    }
    sessions = cached.sessions
    agents = cached.agents
    usage = cached.usage ?? usage
    server = cached.server ?? server
    cachedMessagesBySession = cached.messagesBySession
    messages = cachedMessagesBySession[profile.currentSessionKey] ?? []

    guard !profile.gatewayURL.isEmpty, !profile.token.isEmpty else {
      connectionDetail = "Add a gateway URL and token in Settings."
      return
    }
    await connect(reason: .connecting)
  }

  func handleScenePhase(_ phase: ScenePhase) async {
    if phase == .active {
      await reconnectIfNeeded()
    }
  }

  func saveSettings() async {
    try? try? configurationStore.saveProfile(profile)
    await persistCache()
    await connect(reason: connectionPhase == .connected ? .reconnecting : .connecting)
  }

  func sendDraft() async {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }

    let echo = ChatMessage(
      id: UUID().uuidString.lowercased(),
      sessionKey: profile.currentSessionKey,
      role: .user,
      text: trimmed,
      createdAt: Date(),
      isStreaming: false,
      source: "local"
    )
    messages.append(echo)
    draft = ""
    await persistCache()

    do {
      _ = try await gatewayClient.request(
        method: "chat.send",
        params: [
          "sessionKey": profile.currentSessionKey,
          "message": trimmed,
          "deliver": false,
          "idempotencyKey": UUID().uuidString.lowercased(),
        ]
      )
    } catch {
      lastError = error.localizedDescription
      let failure = ChatMessage(
        id: UUID().uuidString.lowercased(),
        sessionKey: profile.currentSessionKey,
        role: .assistant,
        text: "Error: \(error.localizedDescription)",
        createdAt: Date(),
        isStreaming: false,
        source: "gateway"
      )
      messages.append(failure)
      await persistCache()
    }
  }

  func runQuickAction(_ action: QuickAction) async {
    draft = action.prompt
    await sendDraft()
  }

  func selectSession(_ session: SessionSummary) async {
    profile.currentSessionKey = session.key
    try? try? configurationStore.saveProfile(profile)
    messages = cachedMessagesBySession[session.key] ?? []
    await loadChatHistory()
  }

  func refreshVisiblePage() async {
    guard connectionPhase == .connected else {
      return
    }
    await refreshDashboard()
  }

  func disconnect() async {
    reconnectTask?.cancel()
    reconnectTask = nil
    connectionPhase = .disconnected
    connectionDetail = "Disconnected by user."
    try? await gatewayClient.disconnect()
  }

  private func connect(reason: ConnectionPhase) async {
    connectionPhase = reason
    connectionDetail = reason == .reconnecting ? "Reconnecting to \(profile.gatewayURL)" : "Connecting to \(profile.gatewayURL)"
    lastError = nil

    do {
      let hello = try await gatewayClient.connect(using: profile)
      reconnectAttempt = 0
      reconnectTask?.cancel()
      reconnectTask = nil
      connectionPhase = .connected
      connectionDetail = "Connected as \(profile.displayName)"
      apply(hello: hello)
      try? try? configurationStore.saveProfile(profile)
      await refreshDashboard()
    } catch {
      handleDisconnect(reason: error.localizedDescription)
    }
  }

  private func reconnectIfNeeded() async {
    guard !profile.gatewayURL.isEmpty, !profile.token.isEmpty else {
      return
    }
    if connectionPhase != .connected && connectionPhase != .connecting {
      await connect(reason: .reconnecting)
    }
  }

  private func handleDisconnect(reason: String) {
    if connectionPhase == .disconnected {
      return
    }
    lastError = reason
    connectionPhase = reason.localizedCaseInsensitiveContains("offline") ? .offline : .reconnecting
    connectionDetail = reason
    scheduleReconnectIfNeeded()
  }

  private func handleNetwork(isReachable: Bool) {
    if isReachable {
      Task { await reconnectIfNeeded() }
    } else {
      reconnectTask?.cancel()
      reconnectTask = nil
      connectionPhase = .offline
      connectionDetail = "Network unavailable. Waiting to reconnect."
    }
  }

  private func scheduleReconnectIfNeeded() {
    guard !profile.gatewayURL.isEmpty, !profile.token.isEmpty else {
      return
    }
    reconnectTask?.cancel()
    reconnectAttempt += 1
    let delay = min(pow(1.7, Double(reconnectAttempt)), 15)
    reconnectTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else {
        return
      }
      await self?.reconnectIfNeeded()
    }
  }

  private func apply(hello: GatewayHello) {
    let snapshot = hello.snapshot
    let uptimeMS = snapshot["uptimeMs"] as? Int ?? 0
    let authMode = snapshot["authMode"] as? String
    let health = snapshot["health"] as? [String: Any]
    server = ServerSummary(
      version: hello.serverVersion,
      connectionID: hello.connectionID,
      uptimeSeconds: uptimeMS / 1000,
      heartbeatSeconds: health?["heartbeatSeconds"] as? Int ?? 0,
      isHealthy: (health?["ok"] as? Bool) ?? true,
      authMode: authMode,
      defaultAgentID: health?["defaultAgentId"] as? String,
      sessionCount: (health?["sessions"] as? [String: Any])?["count"] as? Int ?? 0
    )
  }

  private func refreshDashboard() async {
    async let historyTask: Void = loadChatHistory()
    async let sessionsTask: Void = loadSessions()
    async let usageTask: Void = loadUsage()
    async let agentsTask: Void = loadAgents()
    async let healthTask: Void = loadHealth()
    _ = await (historyTask, sessionsTask, usageTask, agentsTask, healthTask)
    await persistCache()
  }

  private func loadChatHistory() async {
    do {
      let payload = try await gatewayClient.request(
        method: "chat.history",
        params: ["sessionKey": profile.currentSessionKey, "limit": 200]
      )
      guard let object = payload as? [String: Any] else {
        return
      }
      let rawMessages = object["messages"] as? [[String: Any]] ?? []
      messages = rawMessages.compactMap { parseChatMessage($0, sessionKey: profile.currentSessionKey) }
      cachedMessagesBySession[profile.currentSessionKey] = messages
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func loadSessions() async {
    do {
      let payload = try await gatewayClient.request(method: "sessions.list", params: [String: Any]())
      guard let object = payload as? [String: Any] else {
        return
      }
      let rows = object["sessions"] as? [[String: Any]] ?? []
      sessions = rows.map { row in
        let key = row["key"] as? String ?? UUID().uuidString.lowercased()
        return SessionSummary(
          id: key,
          key: key,
          label: (row["label"] as? String) ?? key,
          agentID: row["agentId"] as? String,
          model: row["model"] as? String,
          updatedAt: date(fromMilliseconds: row["updatedAt"] ?? row["lastMessageAt"]),
          messageCount: row["messageCount"] as? Int
        )
      }
      if !sessions.contains(where: { $0.key == profile.currentSessionKey }), let first = sessions.first {
        profile.currentSessionKey = first.key
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func loadUsage() async {
    do {
      let now = Date()
      let start = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
      let format = ISO8601DateFormatter()
      format.formatOptions = [.withFullDate]
      async let sessionsUsage = gatewayClient.request(
        method: "sessions.usage",
        params: [
          "startDate": format.string(from: start),
          "endDate": format.string(from: now),
          "limit": 1000,
          "includeContextWeight": true,
        ]
      )
      async let costUsage = gatewayClient.request(
        method: "usage.cost",
        params: [
          "startDate": format.string(from: start),
          "endDate": format.string(from: now),
        ]
      )
      let (sessionUsagePayload, costPayload) = try await (sessionsUsage, costUsage)
      usage = parseUsage(
        sessionsUsage: sessionUsagePayload as? [String: Any] ?? [:],
        costUsage: costPayload as? [String: Any] ?? [:]
      )
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func loadAgents() async {
    do {
      let payload = try await gatewayClient.request(method: "agents.list", params: [String: Any]())
      guard let object = payload as? [String: Any] else {
        return
      }
      let list = object["agents"] as? [[String: Any]] ?? []
      agents = list.map { entry in
        let identity = entry["identity"] as? [String: Any]
        return AgentSummary(
          id: entry["id"] as? String ?? UUID().uuidString.lowercased(),
          name: (identity?["name"] as? String) ?? (entry["name"] as? String) ?? "Agent",
          model: entry["model"] as? String,
          status: (entry["enabled"] as? Bool) == false ? "Disabled" : "Ready",
          summary: (entry["description"] as? String) ?? "Configured on the OpenClaw gateway."
        )
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func loadHealth() async {
    do {
      let payload = try await gatewayClient.request(method: "health", params: [String: Any]())
      guard let object = payload as? [String: Any] else {
        return
      }
      server = ServerSummary(
        version: server.version,
        connectionID: server.connectionID,
        uptimeSeconds: (object["durationMs"] as? Int ?? 0) / 1000,
        heartbeatSeconds: object["heartbeatSeconds"] as? Int ?? server.heartbeatSeconds,
        isHealthy: object["ok"] as? Bool ?? false,
        authMode: server.authMode,
        defaultAgentID: object["defaultAgentId"] as? String ?? server.defaultAgentID,
        sessionCount: ((object["sessions"] as? [String: Any])?["count"] as? Int) ?? server.sessionCount
      )
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func handleGatewayEvent(_ event: GatewayEvent) {
    guard event.name == "chat" else {
      return
    }
    guard let payload = event.payload as? [String: Any] else {
      return
    }
    let sessionKey = payload["sessionKey"] as? String ?? profile.currentSessionKey
    if sessionKey != profile.currentSessionKey {
      return
    }
    let state = payload["state"] as? String ?? "delta"

    if state == "error" {
      let text = payload["errorMessage"] as? String ?? "Request failed."
      messages.append(
        ChatMessage(
          id: UUID().uuidString.lowercased(),
          sessionKey: sessionKey,
          role: .assistant,
          text: text,
          createdAt: Date(),
          isStreaming: false,
          source: "gateway"
        )
      )
      Task { await persistCache() }
      return
    }

    guard let rawMessage = payload["message"] as? [String: Any],
      var parsed = parseChatMessage(rawMessage, sessionKey: sessionKey)
    else {
      return
    }
    parsed.isStreaming = state == "delta"

    if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
      messages[index] = parsed
    } else {
      messages.append(parsed)
    }
    if state == "final" || state == "aborted" {
      messages = messages.map { message in
        var next = message
        next.isStreaming = false
        return next
      }
    }
    cachedMessagesBySession[profile.currentSessionKey] = messages
    Task { await persistCache() }
  }

  private func parseChatMessage(_ raw: [String: Any], sessionKey: String) -> ChatMessage? {
    let role = ChatRole(rawValue: (raw["role"] as? String ?? "assistant").lowercased()) ?? .assistant
    let text: String
    if let direct = raw["text"] as? String {
      text = direct
    } else if let content = raw["content"] as? [[String: Any]] {
      text = content
        .compactMap { block in
          if let blockText = block["text"] as? String {
            return blockText
          }
          if let source = block["source"] as? [String: Any], let data = source["data"] as? String {
            return "[image \(data.prefix(12))…]"
          }
          return nil
        }
        .joined(separator: "\n")
    } else {
      text = ""
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return ChatMessage(
      id: raw["id"] as? String ?? UUID().uuidString.lowercased(),
      sessionKey: sessionKey,
      role: role,
      text: text,
      createdAt: date(fromMilliseconds: raw["timestamp"]) ?? Date(),
      isStreaming: false,
      source: "gateway"
    )
  }

  private func parseUsage(sessionsUsage: [String: Any], costUsage: [String: Any]) -> UsageSummary {
    let sessions = sessionsUsage["sessions"] as? [[String: Any]] ?? []
    let daily = sessionsUsage["days"] as? [[String: Any]] ?? sessionsUsage["daily"] as? [[String: Any]] ?? []
    let points = daily.map { day -> UsagePoint in
      let label = (day["date"] as? String) ?? (day["day"] as? String) ?? "Unknown"
      return UsagePoint(
        id: label,
        dayLabel: label,
        requests: day["requests"] as? Int ?? 0,
        inputTokens: day["inputTokens"] as? Int ?? 0,
        outputTokens: day["outputTokens"] as? Int ?? 0,
        costUSD: day["costUsd"] as? Double ?? day["costUSD"] as? Double ?? 0
      )
    }

    let totalRequests =
      points.reduce(0) { $0 + $1.requests } +
      (sessionsUsage["totalRequests"] as? Int ?? sessions.count)
    let totalInputTokens =
      points.reduce(0) { $0 + $1.inputTokens } +
      (sessionsUsage["inputTokens"] as? Int ?? 0)
    let totalOutputTokens =
      points.reduce(0) { $0 + $1.outputTokens } +
      (sessionsUsage["outputTokens"] as? Int ?? 0)
    let totalCostUSD =
      costUsage["totalUsd"] as? Double ??
      costUsage["totalCostUsd"] as? Double ??
      points.reduce(0) { $0 + $1.costUSD }

    return UsageSummary(
      totalRequests: totalRequests,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      totalCostUSD: totalCostUSD,
      points: points
    )
  }

  private func date(fromMilliseconds raw: Any?) -> Date? {
    if let value = raw as? Int {
      return Date(timeIntervalSince1970: Double(value) / 1000)
    }
    if let value = raw as? Double {
      return Date(timeIntervalSince1970: value / 1000)
    }
    if let value = raw as? String, let parsed = ISO8601DateFormatter().date(from: value) {
      return parsed
    }
    return nil
  }

  private func persistCache() async {
    cachedMessagesBySession[profile.currentSessionKey] = messages
    let cached = CachedAppState(
      profile: profile,
      activeRoute: activeRoute,
      messagesBySession: cachedMessagesBySession,
      sessions: sessions,
      usage: usage,
      agents: agents,
      server: server,
      updatedAt: Date()
    )
    await cacheStore.save(cached)
  }
}
