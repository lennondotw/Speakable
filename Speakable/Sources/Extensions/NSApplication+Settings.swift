import AppKit
import Combine

/// Manager for opening Settings window from non-SwiftUI code
final class SettingsWindowManager {
  static let shared = SettingsWindowManager()

  /// Publisher that emits when settings window should be opened
  let openSettingsPublisher = PassthroughSubject<Void, Never>()

  private init() {}

  /// Request to open the settings window
  /// Call this from AppKit code; SwiftUI views subscribe to openSettingsPublisher
  func requestOpenSettings() {
    NSApp.activate(ignoringOtherApps: true)
    openSettingsPublisher.send()
  }
}
