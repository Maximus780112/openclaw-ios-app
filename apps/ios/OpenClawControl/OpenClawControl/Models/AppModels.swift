import Foundation

enum ControlRoute: String, CaseIterable, Identifiable, Codable {
  case chat
  case status
  case sessions
  case usage
  case agents
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .chat:
      return "Assistant"
    case .status:
      return "Server Status"
    case .sessions:
      return "Sessions"
    case .usage:
      return "Usage"
    case .agents:
      return "Agents"
    case .settings:
      return "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .chat:
      return "bubble.left.and.bubble.right.fill"
    case .status:
      return "bolt.horizontal.circle.fill"
    case .sessions:
      return "clock.arrow.circlepath"
    case .usage:
      return "chart.bar.xaxis"
    case .agents:
      return "person.3.fill"
    case .settings:
      return "gearshape.fill"
    }
  }
}

enum ConnectionPhase: String, Codable {
  case disconnected
  case connecting
  case connected
  case reconnecting
  case offline

  var label: String {
    switch self {
    case .disconnected: "Disconnected"
    case .connecting: "Connecting"
    case .connected: "Connected"
    case .reconnecting: "Reconnecting"
    case .offline: "Offline"
    }
  }
}

enum ChatRole: String, Codable {
  case system
  case user
  case assistant
  case tool
}

struct ConnectionProfile: Codable, Equatable {
  var gatewayURL: String
  var token: String
  var deviceID: String
  var clientInstanceID: String
  var currentSessionKey: String
  var displayName: String

  static func bootstrapDefaults(
    gatewayURL: String,
    token: String,
    displayName: String
  ) -> ConnectionProfile {
    ConnectionProfile(
      gatewayURL: gatewayURL,
      token: token,
      deviceID: UUID().uuidString.lowercased(),
      clientInstanceID: UUID().uuidString.lowercased(),
      currentSessionKey: "main",
      displayName: displayName
    )
  }
}

struct QuickAction: Identifiable, Hashable {
  let id: String
  let title: String
  let prompt: String

  static let defaults: [QuickAction] = [
    QuickAction(
      id: "status",
      title: "Check health",
      prompt: "Check system health and summarize anything that needs attention."
    ),
    QuickAction(
      id: "sessions",
      title: "Review sessions",
      prompt: "Summarize the most active sessions from today."
    ),
    QuickAction(
      id: "usage",
      title: "Usage snapshot",
      prompt: "Give me a cost and token usage snapshot for the current server."
    ),
    QuickAction(
      id: "agents",
      title: "Agent overview",
      prompt: "List enabled agents and what each one is responsible for."
    ),
  ]
}

struct ChatMessage: Identifiable, Codable, Hashable {
  let id: String
  let sessionKey: String
  let role: ChatRole
  var text: String
  let createdAt: Date
  var isStreaming: Bool
  var source: String?
}

struct SessionSummary: Identifiable, Codable, Hashable {
  let id: String
  let key: String
  var label: String
  var agentID: String?
  var model: String?
  var updatedAt: Date?
  var messageCount: Int?
}

struct UsagePoint: Identifiable, Codable, Hashable {
  let id: String
  let dayLabel: String
  let requests: Int
  let inputTokens: Int
  let outputTokens: Int
  let costUSD: Double
}

struct UsageSummary: Codable, Hashable {
  var totalRequests: Int
  var totalInputTokens: Int
  var totalOutputTokens: Int
  var totalCostUSD: Double
  var points: [UsagePoint]
}

struct AgentSummary: Identifiable, Codable, Hashable {
  let id: String
  var name: String
  var model: String?
  var status: String
  var summary: String
}

struct ServerSummary: Codable, Hashable {
  var version: String
  var connectionID: String?
  var uptimeSeconds: Int
  var heartbeatSeconds: Int
  var isHealthy: Bool
  var authMode: String?
  var defaultAgentID: String?
  var sessionCount: Int
}

struct CachedAppState: Codable {
  var profile: ConnectionProfile?
  var activeRoute: ControlRoute
  var messagesBySession: [String: [ChatMessage]]
  var sessions: [SessionSummary]
  var usage: UsageSummary?
  var agents: [AgentSummary]
  var server: ServerSummary?
  var updatedAt: Date

  static let empty = CachedAppState(
    profile: nil,
    activeRoute: .chat,
    messagesBySession: [:],
    sessions: [],
    usage: nil,
    agents: [],
    server: nil,
    updatedAt: .distantPast
  )
}

struct GatewayHello {
  var protocolVersion: Int
  var serverVersion: String
  var connectionID: String?
  var tickIntervalMS: Int?
  var authRole: String?
  var authScopes: [String]
  var snapshot: [String: Any]
}

struct GatewayEvent {
  let name: String
  let payload: Any?
  let sequence: Int?
}

struct GatewayDisconnectReason: Error {
  let message: String
}
