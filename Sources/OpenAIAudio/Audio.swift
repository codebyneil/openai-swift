import Foundation
import OpenAICore

/// A request to transcribe audio into the input language.
///
/// The transcription endpoint converts audio into text in the same language as the audio.
///
/// ## Example
/// ```swift
/// let audioData = try Data(contentsOf: audioFileURL)
/// let request = TranscriptionRequest(
///     file: audioData,
///     model: "whisper-1",
///     language: "en",
///     responseFormat: .json
/// )
/// ```
public struct TranscriptionRequest {
    /// The audio file data to transcribe, in one of these formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, or webm.
    public let file: Data

    /// ID of the model to use. Only `whisper-1` is currently available.
    public let model: String

    /// The language of the input audio. Supplying the input language in ISO-639-1 format will improve accuracy and latency.
    public let language: String?

    /// An optional text to guide the model's style or continue a previous audio segment. The prompt should match the audio language.
    public let prompt: String?

    /// The format of the transcript output. Defaults to json if not specified.
    public let responseFormat: AudioFormat?

    /// The sampling temperature, between 0 and 1. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. If set to 0, the model will use log probability to automatically increase the temperature until certain thresholds are hit.
    public let temperature: Double?

    /// The timestamp granularities to populate for this transcription. Any of these options: `word`, or `segment`. Note: There is no additional latency for segment timestamps, but generating word timestamps incurs additional latency.
    public let timestampGranularities: [TimestampGranularity]?

    /**
     Creates a new transcription request.
    
     - Parameters:
        - file: The audio file data to transcribe
        - model: ID of the model to use (e.g., "whisper-1")
        - language: Optional language of the input audio in ISO-639-1 format
        - prompt: Optional text to guide the model's style
        - responseFormat: Optional format of the transcript output
        - temperature: Optional sampling temperature between 0 and 1
        - timestampGranularities: Optional timestamp granularities to include
     */
    public init(
        file: Data,
        model: String,
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: AudioFormat? = nil,
        temperature: Double? = nil,
        timestampGranularities: [TimestampGranularity]? = nil
    ) {
        self.file = file
        self.model = model
        self.language = language
        self.prompt = prompt
        self.responseFormat = responseFormat
        self.temperature = temperature
        self.timestampGranularities = timestampGranularities
    }
}

/// A request to translate audio into English.
///
/// The translation endpoint converts audio in any supported language into English text.
///
/// ## Example
/// ```swift
/// let audioData = try Data(contentsOf: audioFileURL)
/// let request = TranslationRequest(
///     file: audioData,
///     model: "whisper-1",
///     responseFormat: .json
/// )
/// ```
///
/// - Note: The translation endpoint only supports translation into English at this time.
public struct TranslationRequest {
    /// The audio file data to translate, in one of these formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, or webm.
    public let file: Data

    /// ID of the model to use. Only `whisper-1` is currently available.
    public let model: String

    /// An optional text to guide the model's style or continue a previous audio segment. The prompt should be in English.
    public let prompt: String?

    /// The format of the transcript output. Defaults to json if not specified.
    public let responseFormat: AudioFormat?

    /// The sampling temperature, between 0 and 1. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. If set to 0, the model will use log probability to automatically increase the temperature until certain thresholds are hit.
    public let temperature: Double?

    /**
     Creates a new translation request.
    
     - Parameters:
        - file: The audio file data to translate
        - model: ID of the model to use (e.g., "whisper-1")
        - prompt: Optional text to guide the model's style (should be in English)
        - responseFormat: Optional format of the transcript output
        - temperature: Optional sampling temperature between 0 and 1
     */
    public init(
        file: Data,
        model: String,
        prompt: String? = nil,
        responseFormat: AudioFormat? = nil,
        temperature: Double? = nil
    ) {
        self.file = file
        self.model = model
        self.prompt = prompt
        self.responseFormat = responseFormat
        self.temperature = temperature
    }
}

/// Supported audio formats for input/output operations.
///
/// This enum represents the various formats supported by OpenAI's audio APIs:
/// - Transcription/Translation response formats: json, text, srt, verbose_json, vtt
/// - Text-to-Speech output formats: mp3, opus, aac, flac, wav, pcm
public enum AudioFormat: String, Codable, Sendable {
    /// JSON format with basic transcription data
    case json

    /// Plain text format containing only the transcribed text
    case text

    /// SubRip subtitle format with timestamps
    case srt

    /// JSON format with additional metadata including timestamps, confidence scores, and more detailed information
    case verboseJson = "verbose_json"

    /// WebVTT (Web Video Text Tracks) subtitle format
    case vtt

    /// MP3 audio format (default for text-to-speech)
    case mp3

    /// Opus audio format (optimized for internet streaming)
    case opus

    /// AAC (Advanced Audio Coding) format
    case aac

    /// FLAC (Free Lossless Audio Codec) format
    case flac

    /// WAV (Waveform Audio File Format)
    case wav

    /// Raw PCM (Pulse Code Modulation) audio data
    case pcm
}

/// The level of detail for timestamps in transcription responses.
///
/// When requesting timestamps in a transcription, you can choose between:
/// - `word`: Provides timestamps for individual words (incurs additional latency)
/// - `segment`: Provides timestamps for transcript segments (no additional latency)
public enum TimestampGranularity: String, Codable, Sendable {
    /// Word-level timestamps - provides start and end times for each word
    case word

    /// Segment-level timestamps - provides start and end times for transcript segments
    case segment
}

/// The response from a transcription or translation request.
///
/// Contains the transcribed/translated text and optional metadata depending on the requested format and timestamp granularities.
///
/// ## Example
/// ```swift
/// let response = try await openAI.createTranscription(request)
/// print("Transcribed text: \(response.text)")
///
/// if let language = response.language {
///     print("Detected language: \(language)")
/// }
///
/// // Access word-level timestamps if requested
/// response.words?.forEach { word in
///     print("\(word.word): \(word.start)s - \(word.end)s")
/// }
/// ```
public struct TranscriptionResponse: Codable, Sendable {
    /// The transcribed or translated text
    public let text: String

    /// The language of the input audio (ISO-639-1 format). Only present in transcription responses.
    public let language: String?

    /// Duration of the input audio in seconds. Only present when using verbose_json format.
    public let duration: Double?

    /// Word-level timestamps. Only present when word-level timestamp_granularities are requested.
    public let words: [Word]?

    /// Segment-level information. Only present when using verbose_json format or segment timestamp_granularities.
    public let segments: [Segment]?
}

/// Represents a single word with its timing information in a transcription.
///
/// Word-level timestamps are only available when specifically requested via `timestampGranularities` parameter.
public struct Word: Codable, Sendable {
    /// The transcribed word
    public let word: String

    /// Start time of the word in seconds
    public let start: Double

    /// End time of the word in seconds
    public let end: Double
}

/// Represents a segment of transcribed audio with detailed metadata.
///
/// Segments are logical divisions of the transcript that include timing information,
/// confidence metrics, and other metadata. Available when using verbose_json format.
public struct Segment: Codable, Sendable {
    /// Unique identifier for this segment
    public let id: Int

    /// Seek position in the audio file
    public let seek: Int

    /// Start time of the segment in seconds
    public let start: Double

    /// End time of the segment in seconds
    public let end: Double

    /// The transcribed text for this segment
    public let text: String

    /// Array of token IDs for the segment
    public let tokens: [Int]

    /// Temperature value used for this segment
    public let temperature: Double

    /// Average log probability of the segment
    public let avgLogprob: Double

    /// Compression ratio of the segment (higher values may indicate hallucination)
    public let compressionRatio: Double

    /// Probability that the segment contains no speech
    public let noSpeechProb: Double

    private enum CodingKeys: String, CodingKey {
        case id, seek, start, end, text, tokens, temperature
        case avgLogprob = "avg_logprob"
        case compressionRatio = "compression_ratio"
        case noSpeechProb = "no_speech_prob"
    }
}

// MARK: - Speech Synthesis

/// A request to generate audio from text using text-to-speech.
///
/// The TTS (text-to-speech) endpoint generates lifelike spoken audio from text input.
///
/// ## Example
/// ```swift
/// let request = TextToSpeechRequest(
///     model: "tts-1",
///     input: "Hello, this is a test of text to speech.",
///     voice: .alloy,
///     responseFormat: .mp3,
///     speed: 1.0
/// )
/// ```
///
/// - Note: The maximum length for input text is 4096 characters.
public struct TextToSpeechRequest: Codable, Sendable {
    /// ID of the model to use. One of the available TTS models: `tts-1` or `tts-1-hd`
    public let model: String

    /// The text to generate audio for. Maximum length is 4096 characters.
    public let input: String

    /// The voice to use for generation
    public let voice: Voice

    /// The format to return the audio in. Defaults to mp3 if not specified.
    public let responseFormat: AudioFormat?

    /// The speed of the generated audio. Select a value from 0.25 to 4.0. 1.0 is the default.
    public let speed: Double?

    /**
     Creates a new text-to-speech request.
    
     - Parameters:
        - model: ID of the model to use (e.g., "tts-1" or "tts-1-hd")
        - input: The text to generate audio for (max 4096 characters)
        - voice: The voice to use for generation
        - responseFormat: Optional audio format for the output (defaults to mp3)
        - speed: Optional speed of the generated audio (0.25 to 4.0, default is 1.0)
     */
    public init(
        model: String,
        input: String,
        voice: Voice,
        responseFormat: AudioFormat? = nil,
        speed: Double? = nil
    ) {
        self.model = model
        self.input = input
        self.voice = voice
        self.responseFormat = responseFormat
        self.speed = speed
    }

    private enum CodingKeys: String, CodingKey {
        case model, input, voice, speed
        case responseFormat = "response_format"
    }
}

/// Available voices for text-to-speech generation.
///
/// Each voice has its own unique characteristics:
/// - `alloy`: A balanced, versatile voice
/// - `echo`: A smooth, clear voice
/// - `fable`: A warm, expressive voice
/// - `onyx`: A deep, authoritative voice
/// - `nova`: A friendly, conversational voice
/// - `shimmer`: A soft, gentle voice
///
/// ## Example
/// ```swift
/// let request = TextToSpeechRequest(
///     model: "tts-1",
///     input: "Hello world!",
///     voice: .nova
/// )
/// ```
public enum Voice: String, Codable, Sendable {
    /// A balanced, versatile voice
    case alloy

    /// A smooth, clear voice
    case echo

    /// A warm, expressive voice
    case fable

    /// A deep, authoritative voice
    case onyx

    /// A friendly, conversational voice
    case nova

    /// A soft, gentle voice
    case shimmer
}
