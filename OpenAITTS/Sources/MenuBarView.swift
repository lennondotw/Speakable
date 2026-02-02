import SwiftUI

struct MenuBarView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = AudioPlayer.shared

  var body: some View {
    Group {
      statusItem
      Divider()
      playbackSection
      Divider()
      settingsButton
      quitButton
    }
  }

  // MARK: - Status Item

  private var statusItem: some View {
    Label(statusText, systemImage: statusIcon)
      .disabled(true)
  }

  private var statusText: String {
    settings.isConfigured ? "Ready" : "API Key not set"
  }

  private var statusIcon: String {
    settings.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
  }

  // MARK: - Playback Section

  @ViewBuilder
  private var playbackSection: some View {
    if isActivePlaybackState {
      playPauseButton
      stopButton
    } else {
      playbackStatusLabel
    }
  }

  private var isActivePlaybackState: Bool {
    switch player.state {
    case .playing, .paused:
      return true
    case .idle, .loading, .error:
      return false
    }
  }

  private var playPauseButton: some View {
    Button(playPauseTitle, action: player.togglePlayPause)
      .keyboardShortcut("p", modifiers: [])
  }

  private var playPauseTitle: String {
    player.isPlaying ? "Pause" : "Resume"
  }

  private var stopButton: some View {
    Button("Stop", action: player.stop)
      .keyboardShortcut("s", modifiers: [])
  }

  @ViewBuilder
  private var playbackStatusLabel: some View {
    switch player.state {
    case .loading:
      Label("Loading...", systemImage: "ellipsis")
        .disabled(true)
    case .error:
      Label("Error occurred", systemImage: "exclamationmark.circle")
        .disabled(true)
    case .idle, .playing, .paused:
      Text("No audio playing")
        .disabled(true)
    }
  }

  // MARK: - Menu Buttons

  private var settingsButton: some View {
    Button("Settings...", action: openSettings)
      .keyboardShortcut(",", modifiers: .command)
  }

  private var quitButton: some View {
    Button("Quit OpenAI TTS") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }

  // MARK: - Actions

  private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    if #available(macOS 13.0, *) {
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }
}

#Preview {
  MenuBarView()
    .frame(width: 250)
}