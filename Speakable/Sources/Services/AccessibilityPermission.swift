import AppKit
import ApplicationServices

/// Manages Accessibility permission and selected text retrieval
enum AccessibilityPermission {
  /// Check if Accessibility permission is granted
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  /// Prompt the user to grant Accessibility permission.
  /// Shows a system alert guiding the user to System Settings.
  /// - Returns: `true` if already trusted; `false` if the prompt was shown.
  @discardableResult
  static func requestAccess() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  /// Open System Settings to Accessibility pane
  static func openSystemSettings() {
    let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!
    NSWorkspace.shared.open(url)
  }

  /// Get selected text using Accessibility API
  /// - Returns: The selected text, or nil if not available
  static func getSelectedText() -> String? {
    // Create system-wide accessibility element
    let systemWide = AXUIElementCreateSystemWide()

    // Get the focused element
    var focusedElement: CFTypeRef?
    let focusError = AXUIElementCopyAttributeValue(
      systemWide,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElement
    )

    guard focusError == .success, let focused = focusedElement else {
      return nil
    }

    // Get selected text from focused element
    var selectedText: CFTypeRef?
    let textError = AXUIElementCopyAttributeValue(
      focused as! AXUIElement, // swiftlint:disable:this force_cast
      kAXSelectedTextAttribute as CFString,
      &selectedText
    )

    guard textError == .success, let text = selectedText as? String, !text.isEmpty else {
      return nil
    }

    return text
  }
}
