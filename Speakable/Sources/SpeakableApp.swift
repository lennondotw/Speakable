import SwiftUI

@main
struct SpeakableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra("Speakable", systemImage: "waveform") {
      MenuBarView()
    }

    Window("Settings", id: "settings") {
      SettingsView()
        .frame(minWidth: 600, maxWidth: 600, minHeight: 400, maxHeight: .infinity)
    }
    .defaultSize(width: 600, height: 500)
    .windowResizability(.contentSize)
  }
}
