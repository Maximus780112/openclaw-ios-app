import SwiftUI

struct ShellView: View {
  @ObservedObject var viewModel: AppViewModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var showsPersistentSidebar: Bool {
    horizontalSizeClass == .regular
  }

  var body: some View {
    ZStack(alignment: .leading) {
      ControlTheme.background.ignoresSafeArea()

      HStack(spacing: 0) {
        if showsPersistentSidebar {
          sidebar
            .frame(width: 280)
        }

        activeView
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      if !showsPersistentSidebar && viewModel.drawerPresented {
        Color.black.opacity(0.45)
          .ignoresSafeArea()
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              viewModel.drawerPresented = false
            }
          }
        sidebar
          .frame(width: 290)
          .transition(.move(edge: .leading))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: viewModel.drawerPresented)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("OpenClaw")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(ControlTheme.textPrimary)
          Text("Native control center")
            .font(.subheadline)
            .foregroundStyle(ControlTheme.textSecondary)
        }
        Spacer()
      }

      ConnectionBadge(phase: viewModel.connectionPhase, detail: viewModel.connectionDetail)

      ForEach(ControlRoute.allCases) { route in
        Button {
          viewModel.activeRoute = route
          viewModel.drawerPresented = false
        } label: {
          HStack(spacing: 14) {
            Image(systemName: route.systemImage)
              .frame(width: 20)
            Text(route.title)
              .font(.headline)
            Spacer()
          }
          .padding(.vertical, 12)
          .padding(.horizontal, 14)
          .background(viewModel.activeRoute == route ? ControlTheme.panelRaised : .clear)
          .foregroundStyle(viewModel.activeRoute == route ? ControlTheme.textPrimary : ControlTheme.textSecondary)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Spacer()

      VStack(alignment: .leading, spacing: 6) {
        Text("Gateway")
          .font(.caption.weight(.semibold))
          .foregroundStyle(ControlTheme.textSecondary)
        Text(viewModel.profile.displayName)
          .font(.headline)
          .foregroundStyle(ControlTheme.textPrimary)
        Text(viewModel.profile.gatewayURL)
          .font(.footnote)
          .foregroundStyle(ControlTheme.textSecondary)
          .lineLimit(2)
      }
    }
    .padding(24)
    .background(ControlTheme.panel)
    .overlay(alignment: .trailing) {
      Rectangle().fill(ControlTheme.border).frame(width: 1)
    }
  }

  @ViewBuilder
  private var activeView: some View {
    switch viewModel.activeRoute {
    case .chat:
      ChatHomeView(viewModel: viewModel)
    case .status:
      ServerStatusView(viewModel: viewModel)
    case .sessions:
      SessionsView(viewModel: viewModel)
    case .usage:
      UsageView(viewModel: viewModel)
    case .agents:
      AgentsView(viewModel: viewModel)
    case .settings:
      SettingsView(viewModel: viewModel)
    }
  }
}

