import AVFoundation
import Foundation

// MARK: - Audio Player State

enum AudioPlayerState {
  case idle
  case loading
  case playing
  case paused
  case error(Error)
}

// MARK: - Audio Player

final class AudioPlayer: NSObject, ObservableObject {
  static let shared = AudioPlayer()

  @Published private(set) var state: AudioPlayerState = .idle
  @Published private(set) var progress: Double = 0

  private var player: AVAudioPlayer?
  private var audioQueue: [Data] = []
  private var currentIndex = 0
  private var progressTimer: Timer?

  override private init() {
    super.init()
  }

  /// Play audio from Data
  func play(_ audioData: Data) {
    stop()
    audioQueue = [audioData]
    currentIndex = 0
    playCurrentTrack()
  }

  /// Play multiple audio chunks sequentially
  func playSequence(_ audioChunks: [Data]) {
    stop()
    audioQueue = audioChunks
    currentIndex = 0
    playCurrentTrack()
  }

  private func playCurrentTrack() {
    guard currentIndex < audioQueue.count else {
      state = .idle
      progress = 0
      return
    }

    let audioData = audioQueue[currentIndex]

    do {
      player = try AVAudioPlayer(data: audioData)
      player?.delegate = self
      player?.prepareToPlay()
      player?.play()
      state = .playing
      startProgressTimer()
    } catch {
      state = .error(error)
      print("Failed to play audio: \(error.localizedDescription)")
    }
  }

  func pause() {
    player?.pause()
    state = .paused
    stopProgressTimer()
  }

  func resume() {
    player?.play()
    state = .playing
    startProgressTimer()
  }

  func stop() {
    stopProgressTimer()
    player?.stop()
    player = nil
    audioQueue = []
    currentIndex = 0
    state = .idle
    progress = 0
  }

  func togglePlayPause() {
    switch state {
    case .playing:
      pause()
    case .paused:
      resume()
    default:
      break
    }
  }

  var isPlaying: Bool {
    if case .playing = state {
      return true
    }
    return false
  }

  // MARK: - Progress Timer

  private func startProgressTimer() {
    stopProgressTimer()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.updateProgress()
    }
  }

  private func stopProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = nil
  }

  private func updateProgress() {
    guard let player, player.duration > 0 else {
      progress = 0
      return
    }

    let trackProgress = player.currentTime / player.duration
    let totalTracks = Double(audioQueue.count)
    let completedTracks = Double(currentIndex)

    progress = (completedTracks + trackProgress) / totalTracks
  }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      currentIndex += 1

      if currentIndex < audioQueue.count {
        playCurrentTrack()
      } else {
        stopProgressTimer()
        state = .idle
        progress = 0
      }
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    DispatchQueue.main.async { [weak self] in
      if let error {
        self?.state = .error(error)
      }
      self?.stopProgressTimer()
    }
  }
}
