import KeyboardShortcuts
import SwiftUI
import UserNotifications

struct SettingsView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared
  @StateObject private var permissions = PermissionsManager.shared
  @State private var isTestingVoice = false
  @State private var showingAPIKeyField = false
  @State private var testText = "Hello! This is a test of OpenAI text to speech."

  var body: some View {
    Form {
      permissionsSection

      Section {
        if settings.apiKey.isEmpty || showingAPIKeyField {
          LabeledContent {
            HStack {
              SecureField("sk-...", text: $settings.apiKey)
              if showingAPIKeyField, !settings.apiKey.isEmpty {
                Button("Done") {
                  showingAPIKeyField = false
                }
              }
            }
          } label: {
            Text("API Key")
          }
        } else {
          LabeledContent {
            HStack {
              Text("••••••••" + String(settings.apiKey.suffix(4)))
                .font(.system(.body, design: .monospaced))
              Button("Change") {
                showingAPIKeyField = true
              }
            }
          } label: {
            Text("API Key")
          }
        }
      } header: {
        Text("OpenAI API Key")
      } footer: {
        Text("Stored securely in macOS Keychain.")
      }

      Section {
        Picker("Voice", selection: $settings.selectedVoice) {
          ForEach(TTSVoice.allCases) { voice in
            Text(voice.displayName).tag(voice)
          }
        }

        Picker("Model", selection: $settings.selectedModel) {
          ForEach(TTSModel.allCases) { model in
            Text(model.displayName).tag(model)
          }
        }
      } header: {
        Text("Voice")
      }

      Section {
        LabeledContent("Speed") {
          Text("\(settings.speechSpeed, specifier: "%.2f")x")
            .monospacedDigit()
        }
        Slider(value: $settings.speechSpeed, in: 0.25...4.0)
        Button("Reset to 1.0x") {
          settings.speechSpeed = 1.0
        }
        .disabled(settings.speechSpeed == 1.0)
      } header: {
        Text("Speed")
      }

      Section {
        TextField(
          "e.g. Speak cheerfully, Read slowly...",
          text: $settings.voiceInstructions,
          axis: .vertical
        )
        .lineLimit(2...4)
        .disabled(!settings.selectedModel.supportsInstructions)
      } header: {
        Text("Voice Instructions")
      } footer: {
        Text(
          settings.selectedModel.supportsInstructions
            ? "Available for GPT-4o Mini TTS."
            : "Requires GPT-4o Mini TTS."
        )
        .foregroundColor(settings.selectedModel.supportsInstructions ? .secondary : .orange)
      }

      Section {
        KeyboardShortcuts.Recorder("Open Speak Bar:", name: .openSpeakBar)
        KeyboardShortcuts.Recorder("Speak Selected Text:", name: .speakSelectedText)
        KeyboardShortcuts.Recorder("Speak Clipboard:", name: .speakClipboard)
      } header: {
        Text("Global Hotkeys")
      } footer: {
        Text("Set global keyboard shortcuts to use Speakable from anywhere.")
      }

      Section {
        TextField("Enter test text...", text: $testText, axis: .vertical)
          .lineLimit(2...4)

        Button(buttonTitle, action: testOrStop)
          .disabled(buttonDisabled)
      } header: {
        Text("Test")
      } footer: {
        if !settings.isConfigured {
          Text("Enter your API key to test.")
            .foregroundColor(.orange)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 720)
  }

  private var buttonTitle: String {
    if player.isPlaying { return "Stop" }
    if case .loading = player.state { return "Generating..." }
    return "Test Voice"
  }

  private var buttonDisabled: Bool {
    if player.isPlaying { return false }
    if case .loading = player.state { return false }
    return !settings.isConfigured || testText.isEmpty
  }

  // MARK: - Permissions Section

  private var permissionsSection: some View {
    Section {
      LabeledContent {
        if permissions.accessibilityGranted {
          Text("Granted")
            .foregroundStyle(.secondary)
        } else {
          Button("Give Access") {
            permissions.requestAccessibility()
          }
        }
      } label: {
        Label("Accessibility", systemImage: permissions.accessibilityGranted ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(permissions.accessibilityGranted ? .green : .primary)
      }

      LabeledContent {
        if permissions.notificationStatus == .authorized {
          Text("Granted")
            .foregroundStyle(.secondary)
        } else if permissions.notificationStatus == .denied {
          Button("Open Settings") {
            permissions.openNotificationSettings()
          }
        } else {
          Button("Give Access") {
            permissions.requestNotification()
          }
        }
      } label: {
        Label("Notifications", systemImage: permissions.notificationStatus == .authorized ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(permissions.notificationStatus == .authorized ? .green : .primary)
      }
    } header: {
      Text("Permissions")
    } footer: {
      Text("Accessibility is required to read selected text. Notifications are optional.")
    }
  }

  private func testOrStop() {
    if player.isPlaying {
      player.stop()
      return
    }
    if case .loading = player.state {
      player.stop()
      return
    }

    // Set loading state immediately before API call
    player.state = .loading

    Task {
      do {
        let stream = try await OpenAIClient.shared.generateSpeechStream(
          text: testText,
          voice: settings.selectedVoice,
          model: settings.selectedModel,
          speed: settings.speechSpeed,
          instructions: settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil
        )

        await MainActor.run {
          player.startStreaming(stream)
        }
      } catch {
        await MainActor.run {
          player.state = .idle
          let alert = NSAlert()
          alert.messageText = "Test Failed"
          alert.informativeText = error.localizedDescription
          alert.alertStyle = .warning
          alert.runModal()
        }
      }
    }
  }
}

#Preview {
  SettingsView()
}
