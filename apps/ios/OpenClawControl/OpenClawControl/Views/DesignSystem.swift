import SwiftUI

enum ControlTheme {
  static let background = Color(red: 0.05, green: 0.06, blue: 0.08)
  static let panel = Color(red: 0.09, green: 0.11, blue: 0.15)
  static let panelRaised = Color(red: 0.12, green: 0.14, blue: 0.20)
  static let accent = Color(red: 0.27, green: 0.77, blue: 0.93)
  static let accentMuted = Color(red: 0.18, green: 0.38, blue: 0.46)
  static let success = Color(red: 0.23, green: 0.80, blue: 0.49)
  static let warning = Color(red: 0.92, green: 0.68, blue: 0.29)
  static let danger = Color(red: 0.91, green: 0.39, blue: 0.39)
  static let textPrimary = Color.white
  static let textSecondary = Color.white.opacity(0.7)
  static let border = Color.white.opacity(0.08)
}

struct ControlCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(18)
      .background(ControlTheme.panel)
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .stroke(ControlTheme.border, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

extension View {
  func controlCard() -> some View {
    modifier(ControlCardModifier())
  }

  @ViewBuilder
  func controlTextInputTraits() -> some View {
#if os(iOS) || os(tvOS) || os(visionOS)
    self
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
#else
    self
#endif
  }
}
