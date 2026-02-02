import SwiftUI

@main
struct SpeakableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra("Speakable", systemImage: "waveform") {
      MenuBarView()
    }

    Settings {
      SettingsView()
    }
  }
}
