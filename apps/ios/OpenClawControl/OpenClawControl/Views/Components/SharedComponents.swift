import SwiftUI

struct ConnectionBadge: View {
  let phase: ConnectionPhase
  let detail: String

  private var tint: Color {
    switch phase {
    case .connected: ControlTheme.success
    case .connecting, .reconnecting: ControlTheme.warning
    case .offline, .disconnected: ControlTheme.danger
    }
  }

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(tint)
        .frame(width: 10, height: 10)
      VStack(alignment: .leading, spacing: 2) {
        Text(phase.label)
          .font(.headline)
          .foregroundStyle(ControlTheme.textPrimary)
        Text(detail)
          .font(.caption)
          .foregroundStyle(ControlTheme.textSecondary)
          .lineLimit(2)
      }
      Spacer()
    }
    .padding(14)
    .background(ControlTheme.panelRaised)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct MetricCard: View {
  let title: String
  let value: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(ControlTheme.textSecondary)
      Text(value)
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .foregroundStyle(ControlTheme.textPrimary)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(ControlTheme.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .controlCard()
  }
}

struct EmptyStateView: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(ControlTheme.accent)
      Text(title)
        .font(.headline)
        .foregroundStyle(ControlTheme.textPrimary)
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(ControlTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 220)
    .controlCard()
  }
}

