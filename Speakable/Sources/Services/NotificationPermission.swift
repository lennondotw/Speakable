import AppKit
import UserNotifications

/// Manages Notification permission
enum NotificationPermission {
  /// Check current notification authorization status
  static func checkStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  /// Request notification permission
  /// - Returns: true if granted, false otherwise
  @discardableResult
  static func request() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert,
        .sound,
      ])
    } catch {
      return false
    }
  }

  /// Open System Settings to Notifications pane for this app
  static func openSystemSettings() {
    if let bundleId = Bundle.main.bundleIdentifier,
       let url = URL(
         string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleId)"
       )
    {
      NSWorkspace.shared.open(url)
    }
  }
}
