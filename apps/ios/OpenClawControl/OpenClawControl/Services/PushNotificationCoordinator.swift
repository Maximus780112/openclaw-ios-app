#if canImport(UIKit)
import Foundation
import UIKit

@MainActor
final class PushNotificationCoordinator: NSObject, UIApplicationDelegate, ObservableObject {
  @Published private(set) var pushTokenHex: String?

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    pushTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pushTokenHex = nil
    print("Push registration not enabled: \(error.localizedDescription)")
  }
}
#endif
