import SwiftUI

struct ChatHomeView: View {
  @ObservedObject var viewModel: AppViewModel

  private var filteredMessages: [ChatMessage] {
    let query = viewModel.chatSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return viewModel.messages
    }
    return viewModel.messages.filter {
      $0.text.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          quickActions
          if filteredMessages.isEmpty {
            EmptyStateView(
              title: "No messages yet",
              subtitle: "The app auto-connects to your gateway and restores the current session as soon as history loads.",
              systemImage: "message.badge.waveform.fill"
            )
          } else {
            LazyVStack(spacing: 14) {
              ForEach(filteredMessages) { message in
                messageBubble(message)
              }
            }
          }
        }
        .padding(20)
      }
      composer
    }
  }

  private var header: some View {
    VStack(spacing: 18) {
      HStack(spacing: 14) {
        Button {
          viewModel.drawerPresented.toggle()
        } label: {
          Image(systemName: "sidebar.left")
            .font(.title3)
            .foregroundStyle(ControlTheme.textPrimary)
            .frame(width: 44, height: 44)
            .background(ControlTheme.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Assistant")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(ControlTheme.textPrimary)
          Text("Session \(viewModel.profile.currentSessionKey)")
            .font(.subheadline)
            .foregroundStyle(ControlTheme.textSecondary)
        }
        Spacer()
      }

      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(ControlTheme.textSecondary)
        TextField("Search messages", text: $viewModel.chatSearchText)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .foregroundStyle(ControlTheme.textPrimary)
        if !viewModel.chatSearchText.isEmpty {
          Button("Clear") {
            viewModel.chatSearchText = ""
          }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(ControlTheme.accent)
        }
      }
      .padding(14)
      .background(ControlTheme.panel)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 10)
    .background(ControlTheme.background.opacity(0.98))
  }

  private var quickActions: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(viewModel.quickActions) { action in
          Button {
            Task { await viewModel.runQuickAction(action) }
          } label: {
            Text(action.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(ControlTheme.textPrimary)
              .padding(.vertical, 10)
              .padding(.horizontal, 16)
              .background(
                Capsule(style: .continuous)
                  .fill(ControlTheme.panelRaised)
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func messageBubble(_ message: ChatMessage) -> some View {
    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
      HStack {
        if message.role == .user {
          Spacer()
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(message.role.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ControlTheme.textSecondary)
          Text(message.text)
            .font(.body)
            .foregroundStyle(ControlTheme.textPrimary)
          if message.isStreaming {
            ProgressView()
              .tint(ControlTheme.accent)
          }
        }
        .padding(16)
        .background(message.role == .user ? ControlTheme.accentMuted : ControlTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: 420, alignment: message.role == .user ? .trailing : .leading)
        if message.role != .user {
          Spacer()
        }
      }
      Text(message.createdAt.formatted(date: .omitted, time: .shortened))
        .font(.caption2)
        .foregroundStyle(ControlTheme.textSecondary)
        .padding(.horizontal, 4)
    }
  }

  private var composer: some View {
    VStack(spacing: 12) {
      if let lastError = viewModel.lastError {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(ControlTheme.warning)
          Text(lastError)
            .font(.footnote)
            .foregroundStyle(ControlTheme.textSecondary)
          Spacer()
        }
      }
      HStack(alignment: .bottom, spacing: 12) {
        TextField("Message OpenClaw", text: $viewModel.draft, axis: .vertical)
          .textFieldStyle(.plain)
          .foregroundStyle(ControlTheme.textPrimary)
          .lineLimit(1 ... 6)

        Button {
          Task { await viewModel.sendDraft() }
        } label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 34))
            .foregroundStyle(ControlTheme.accent)
        }
        .disabled(viewModel.connectionPhase != .connected)
      }
      .padding(16)
      .background(ControlTheme.panel)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    .padding(20)
    .background(ControlTheme.background.opacity(0.98))
  }
}

