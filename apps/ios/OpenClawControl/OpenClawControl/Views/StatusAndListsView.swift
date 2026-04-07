import Charts
import SwiftUI

struct ServerStatusView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        topBar(title: "Server Status")
        HStack(spacing: 14) {
          MetricCard(title: "Version", value: viewModel.server.version, subtitle: "Gateway build")
          MetricCard(
            title: "Health",
            value: viewModel.server.isHealthy ? "Healthy" : "Degraded",
            subtitle: "Heartbeat \(viewModel.server.heartbeatSeconds)s"
          )
        }
        HStack(spacing: 14) {
          MetricCard(
            title: "Sessions",
            value: "\(viewModel.server.sessionCount)",
            subtitle: "Tracked in the current snapshot"
          )
          MetricCard(
            title: "Default Agent",
            value: viewModel.server.defaultAgentID ?? "None",
            subtitle: viewModel.server.authMode ?? "auth mode unknown"
          )
        }
        VStack(alignment: .leading, spacing: 12) {
          Text("Connection")
            .font(.headline)
            .foregroundStyle(ControlTheme.textPrimary)
          Text("Gateway URL: \(viewModel.profile.gatewayURL)")
          Text("Session key: \(viewModel.profile.currentSessionKey)")
          Text("Connection ID: \(viewModel.server.connectionID ?? "pending")")
          Text("Uptime: \(viewModel.server.uptimeSeconds)s")
        }
        .font(.subheadline)
        .foregroundStyle(ControlTheme.textSecondary)
        .controlCard()
      }
      .padding(20)
    }
    .task {
      await viewModel.refreshVisiblePage()
    }
  }

  private func topBar(title: String) -> some View {
    HStack {
      Button {
        viewModel.drawerPresented.toggle()
      } label: {
        Image(systemName: "sidebar.left")
          .foregroundStyle(ControlTheme.textPrimary)
          .frame(width: 42, height: 42)
          .background(ControlTheme.panel)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Spacer()
    }
  }
}

struct SessionsView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        titleRow("Sessions")
        if viewModel.sessions.isEmpty {
          EmptyStateView(
            title: "No sessions cached yet",
            subtitle: "Connected gateways will populate this list from `sessions.list`.",
            systemImage: "clock.badge.xmark.fill"
          )
        } else {
          ForEach(viewModel.sessions) { session in
            Button {
              Task { await viewModel.selectSession(session) }
            } label: {
              HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                  Text(session.label)
                    .font(.headline)
                    .foregroundStyle(ControlTheme.textPrimary)
                  Text(session.key)
                    .font(.footnote)
                    .foregroundStyle(ControlTheme.textSecondary)
                  Text(session.model ?? session.agentID ?? "No model override")
                    .font(.caption)
                    .foregroundStyle(ControlTheme.textSecondary)
                }
                Spacer()
                if session.key == viewModel.profile.currentSessionKey {
                  Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ControlTheme.accent)
                }
              }
              .controlCard()
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(20)
    }
  }

  private func titleRow(_ title: String) -> some View {
    HStack {
      Button {
        viewModel.drawerPresented.toggle()
      } label: {
        Image(systemName: "sidebar.left")
          .foregroundStyle(ControlTheme.textPrimary)
          .frame(width: 42, height: 42)
          .background(ControlTheme.panel)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Spacer()
    }
  }
}

struct UsageView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        titleRow("Usage")
        HStack(spacing: 14) {
          MetricCard(title: "Requests", value: "\(viewModel.usage.totalRequests)", subtitle: "Rolling seven days")
          MetricCard(title: "Cost", value: String(format: "$%.2f", viewModel.usage.totalCostUSD), subtitle: "Estimated total")
        }
        HStack(spacing: 14) {
          MetricCard(title: "Input", value: "\(viewModel.usage.totalInputTokens)", subtitle: "Prompt tokens")
          MetricCard(title: "Output", value: "\(viewModel.usage.totalOutputTokens)", subtitle: "Completion tokens")
        }
        VStack(alignment: .leading, spacing: 12) {
          Text("Daily Trend")
            .font(.headline)
            .foregroundStyle(ControlTheme.textPrimary)
          if viewModel.usage.points.isEmpty {
            Text("No usage data returned by the gateway yet.")
              .font(.subheadline)
              .foregroundStyle(ControlTheme.textSecondary)
          } else {
            Chart(viewModel.usage.points) { point in
              BarMark(
                x: .value("Day", point.dayLabel),
                y: .value("Requests", point.requests)
              )
              .foregroundStyle(ControlTheme.accent)
            }
            .frame(height: 220)
          }
        }
        .controlCard()
      }
      .padding(20)
    }
  }

  private func titleRow(_ title: String) -> some View {
    HStack {
      Button {
        viewModel.drawerPresented.toggle()
      } label: {
        Image(systemName: "sidebar.left")
          .foregroundStyle(ControlTheme.textPrimary)
          .frame(width: 42, height: 42)
          .background(ControlTheme.panel)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Spacer()
    }
  }
}

struct AgentsView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        titleRow("Agents")
        if viewModel.agents.isEmpty {
          EmptyStateView(
            title: "No agents returned yet",
            subtitle: "This view mirrors the `agents.list` control UI surface.",
            systemImage: "person.2.slash.fill"
          )
        } else {
          ForEach(viewModel.agents) { agent in
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text(agent.name)
                  .font(.headline)
                  .foregroundStyle(ControlTheme.textPrimary)
                Spacer()
                Text(agent.status)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(agent.status == "Ready" ? ControlTheme.success : ControlTheme.warning)
              }
              Text(agent.model ?? "No explicit model")
                .font(.subheadline)
                .foregroundStyle(ControlTheme.textSecondary)
              Text(agent.summary)
                .font(.footnote)
                .foregroundStyle(ControlTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlCard()
          }
        }
      }
      .padding(20)
    }
  }

  private func titleRow(_ title: String) -> some View {
    HStack {
      Button {
        viewModel.drawerPresented.toggle()
      } label: {
        Image(systemName: "sidebar.left")
          .foregroundStyle(ControlTheme.textPrimary)
          .frame(width: 42, height: 42)
          .background(ControlTheme.panel)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Spacer()
    }
  }
}

struct SettingsView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        titleRow("Settings")
        Group {
          labeledField("Gateway URL", text: $viewModel.profile.gatewayURL, secure: false)
          labeledField("Token", text: $viewModel.profile.token, secure: true)
          labeledField("Display Name", text: $viewModel.profile.displayName, secure: false)
        }
        .controlCard()

        VStack(alignment: .leading, spacing: 12) {
          Text("Secure Identifiers")
            .font(.headline)
            .foregroundStyle(ControlTheme.textPrimary)
          Text("Device ID: \(viewModel.profile.deviceID)")
          Text("Client instance: \(viewModel.profile.clientInstanceID)")
          Text("Current session: \(viewModel.profile.currentSessionKey)")
        }
        .font(.footnote)
        .foregroundStyle(ControlTheme.textSecondary)
        .controlCard()

        HStack(spacing: 14) {
          Button("Save and Reconnect") {
            Task { await viewModel.saveSettings() }
          }
          .buttonStyle(.borderedProminent)
          .tint(ControlTheme.accent)

          Button("Disconnect") {
            Task { await viewModel.disconnect() }
          }
          .buttonStyle(.bordered)
          .tint(ControlTheme.danger)
        }
      }
      .padding(20)
    }
  }

  private func titleRow(_ title: String) -> some View {
    HStack {
      Button {
        viewModel.drawerPresented.toggle()
      } label: {
        Image(systemName: "sidebar.left")
          .foregroundStyle(ControlTheme.textPrimary)
          .frame(width: 42, height: 42)
          .background(ControlTheme.panel)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Spacer()
    }
  }

  @ViewBuilder
  private func labeledField(_ title: String, text: Binding<String>, secure: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ControlTheme.textSecondary)
      if secure {
        SecureField(title, text: text)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .foregroundStyle(ControlTheme.textPrimary)
      } else {
        TextField(title, text: text)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .foregroundStyle(ControlTheme.textPrimary)
      }
      Divider().overlay(ControlTheme.border)
    }
  }
}

