import Combine
import SwiftUI
import UserNotifications

/// Observable manager for tracking permission states
@MainActor
final class PermissionsManager: ObservableObject {
  static let shared = PermissionsManager()

  @Published private(set) var accessibilityGranted = false
  @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

  private var timer: Timer?

  private init() {
    refreshAll()
    startPolling()
  }

  deinit {
    timer?.invalidate()
  }

  /// Refresh all permission states
  func refreshAll() {
    accessibilityGranted = AccessibilityPermission.isGranted

    Task {
      let status = await NotificationPermission.checkStatus()
      await MainActor.run {
        notificationStatus = status
      }
    }
  }

  /// Start polling for permission changes (accessibility doesn't have callbacks)
  private func startPolling() {
    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refreshAll()
      }
    }
  }

  // MARK: - Accessibility

  func requestAccessibility() {
    AccessibilityPermission.request()
    // Refresh after a short delay to catch the change
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.refreshAll()
    }
  }

  func openAccessibilitySettings() {
    AccessibilityPermission.openSystemSettings()
  }

  // MARK: - Notifications

  func requestNotification() {
    Task {
      await NotificationPermission.request()
      refreshAll()
    }
  }

  func openNotificationSettings() {
    NotificationPermission.openSystemSettings()
  }
}
