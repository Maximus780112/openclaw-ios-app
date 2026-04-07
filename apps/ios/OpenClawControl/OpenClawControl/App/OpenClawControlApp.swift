import SwiftUI

@main
struct OpenClawControlApp: App {
  @UIApplicationDelegateAdaptor(PushNotificationCoordinator.self) private var pushCoordinator
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var viewModel = AppViewModel(container: AppContainer())

  var body: some Scene {
    WindowGroup {
      ShellView(viewModel: viewModel)
        .preferredColorScheme(.dark)
        .task {
          await viewModel.start()
        }
        .onChange(of: scenePhase) { _, newValue in
          Task { await viewModel.handleScenePhase(newValue) }
        }
    }
  }
}

