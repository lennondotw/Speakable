import SwiftUI

@main
struct OpenAITTSApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      SettingsView()
    }

    MenuBarExtra("OpenAI TTS", systemImage: "speaker.wave.2.fill") {
      MenuBarView()
    }
  }
}
