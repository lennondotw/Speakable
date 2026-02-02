import AppKit
import Foundation
import UserNotifications

/// Service Provider that handles the macOS Services menu integration
final class TTSServiceProvider: NSObject {
  private let maxCharacters = 4096

  /// Called by macOS Services when user selects "Speak with OpenAI"
  /// This method name must match NSMessage in Info.plist
  @objc func speakText(
    _ pboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let text = pboard.string(forType: .string), !text.isEmpty else {
      error.pointee = "No text selected" as NSString
      return
    }

    let settings = SettingsManager.shared

    guard settings.isConfigured else {
      error.pointee = "API Key not configured. Please open OpenAI TTS settings." as NSString
      showNotification(
        title: "OpenAI TTS",
        body: "API Key not configured. Please open the app to set up your API key."
      )
      openSettingsWindow()
      return
    }

    // Start TTS in background
    Task {
      await performTTS(text: text)
    }
  }

  private func performTTS(text: String) async {
    let settings = SettingsManager.shared
    let client = OpenAIClient.shared
    let player = AudioPlayer.shared

    do {
      showNotification(title: "OpenAI TTS", body: "Generating speech...")

      let audioData: [Data]

      if text.count > maxCharacters {
        // Split long text into chunks
        audioData = try await client.generateSpeechChunked(
          text: text,
          voice: settings.selectedVoice,
          model: settings.selectedModel,
          speed: settings.speechSpeed,
          instructions: settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil
        )
      } else {
        let data = try await client.generateSpeech(
          text: text,
          voice: settings.selectedVoice,
          model: settings.selectedModel,
          speed: settings.speechSpeed,
          instructions: settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil
        )
        audioData = [data]
      }

      await MainActor.run {
        if audioData.count == 1 {
          player.play(audioData[0])
        } else {
          player.playSequence(audioData)
        }
      }

    } catch let error as OpenAIError {
      await MainActor.run {
        showNotification(title: "OpenAI TTS Error", body: error.localizedDescription)
      }
    } catch {
      await MainActor.run {
        showNotification(title: "OpenAI TTS Error", body: error.localizedDescription)
      }
    }
  }

  private func showNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body

      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )

      center.add(request)
    }
  }

  private func openSettingsWindow() {
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      if #available(macOS 13.0, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
      } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
      }
    }
  }
}
