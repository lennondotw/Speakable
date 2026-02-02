import Foundation

// MARK: - API Errors

enum OpenAIError: LocalizedError {
  case missingAPIKey
  case invalidURL
  case networkError(Error)
  case invalidResponse
  case apiError(statusCode: Int, message: String)
  case textTooLong(length: Int, maxLength: Int)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      "API Key is not configured. Please set your OpenAI API key in settings."
    case .invalidURL:
      "Invalid API URL."
    case let .networkError(error):
      "Network error: \(error.localizedDescription)"
    case .invalidResponse:
      "Invalid response from server."
    case let .apiError(statusCode, message):
      "API error (\(statusCode)): \(message)"
    case let .textTooLong(length, maxLength):
      "Text is too long (\(length) characters). Maximum allowed is \(maxLength) characters."
    }
  }
}

// MARK: - API Response

private struct OpenAIErrorResponse: Decodable {
  struct ErrorDetail: Decodable {
    let message: String
    let type: String?
    let code: String?
  }

  let error: ErrorDetail
}

// MARK: - OpenAI Client

final class OpenAIClient {
  static let shared = OpenAIClient()

  private let baseURL = "https://api.openai.com/v1/audio/speech"
  private let maxCharacters = 4096
  private let session: URLSession

  private init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    config.timeoutIntervalForResource = 120
    session = URLSession(configuration: config)
  }

  /// Generate speech from text using OpenAI TTS API
  /// - Parameters:
  ///   - text: The text to convert to speech (max 4096 characters)
  ///   - voice: The voice to use
  ///   - model: The TTS model to use
  ///   - speed: Speech speed (0.25 to 4.0)
  ///   - instructions: Voice instructions (only for gpt-4o-mini-tts)
  /// - Returns: Audio data in MP3 format
  func generateSpeech(
    text: String,
    voice: TTSVoice = .alloy,
    model: TTSModel = .gpt4oMiniTTS,
    speed: Double = 1.0,
    instructions: String? = nil
  ) async throws -> Data {
    let settings = SettingsManager.shared

    guard !settings.apiKey.isEmpty else {
      throw OpenAIError.missingAPIKey
    }

    // Validate text length
    guard text.count <= maxCharacters else {
      throw OpenAIError.textTooLong(length: text.count, maxLength: maxCharacters)
    }

    guard let url = URL(string: baseURL) else {
      throw OpenAIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Build request body
    var body: [String: Any] = [
      "model": model.rawValue,
      "input": text,
      "voice": voice.rawValue,
      "response_format": "mp3",
      "speed": max(0.25, min(4.0, speed)),
    ]

    // Add instructions for supported models
    if model.supportsInstructions, let instructions, !instructions.isEmpty {
      body["instructions"] = instructions
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    do {
      let (data, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw OpenAIError.invalidResponse
      }

      if httpResponse.statusCode == 200 {
        return data
      }

      // Parse error response
      if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
        throw OpenAIError.apiError(
          statusCode: httpResponse.statusCode,
          message: errorResponse.error.message
        )
      }

      throw OpenAIError.apiError(
        statusCode: httpResponse.statusCode,
        message: "Unknown error"
      )
    } catch let error as OpenAIError {
      throw error
    } catch {
      throw OpenAIError.networkError(error)
    }
  }

  /// Generate speech for long text by splitting into chunks
  /// - Parameters:
  ///   - text: The text to convert (can be longer than 4096 characters)
  ///   - voice: The voice to use
  ///   - model: The TTS model to use
  ///   - speed: Speech speed
  ///   - instructions: Voice instructions
  /// - Returns: Array of audio data chunks
  func generateSpeechChunked(
    text: String,
    voice: TTSVoice = .alloy,
    model: TTSModel = .gpt4oMiniTTS,
    speed: Double = 1.0,
    instructions: String? = nil
  ) async throws -> [Data] {
    let chunks = splitText(text, maxLength: maxCharacters)
    var audioChunks: [Data] = []

    for chunk in chunks {
      let audioData = try await generateSpeech(
        text: chunk,
        voice: voice,
        model: model,
        speed: speed,
        instructions: instructions
      )
      audioChunks.append(audioData)
    }

    return audioChunks
  }

  /// Split text into chunks at sentence boundaries
  private func splitText(_ text: String, maxLength: Int) -> [String] {
    guard text.count > maxLength else {
      return [text]
    }

    var chunks: [String] = []
    var currentChunk = ""

    // Split by sentences
    let sentenceDelimiters = CharacterSet(charactersIn: ".!?。！？")
    let sentences = text.components(separatedBy: sentenceDelimiters)

    for (index, sentence) in sentences.enumerated() {
      var sentenceWithDelimiter = sentence

      // Re-add delimiter if not the last sentence
      if index < sentences.count - 1 {
        let endIndex = text.index(
          text.startIndex,
          offsetBy: min(text.count - 1, currentChunk.count + sentence.count)
        )
        if endIndex < text.endIndex {
          let delimiter = text[endIndex]
          sentenceWithDelimiter += String(delimiter)
        }
      }

      if currentChunk.count + sentenceWithDelimiter.count <= maxLength {
        currentChunk += sentenceWithDelimiter
      } else {
        if !currentChunk.isEmpty {
          chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
        }
        currentChunk = sentenceWithDelimiter
      }
    }

    if !currentChunk.isEmpty {
      chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
    }

    return chunks
  }
}
