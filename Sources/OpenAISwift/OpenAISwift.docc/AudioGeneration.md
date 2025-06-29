# Audio Generation

Transcribe audio and generate speech using OpenAI's audio models.

## Overview

OpenAISwift supports audio transcription with Whisper and text-to-speech generation, enabling you to build voice-enabled applications.

## Audio Transcription

```swift
let audioData = try Data(contentsOf: audioFileURL)
let request = AudioTranscriptionRequest(
    file: audioData,
    model: "whisper-1",
    language: "en",
    temperature: 0
)

let response = try await openAI.createTranscription(request)
print("Transcription: \(response.text)")
```

## Text-to-Speech

```swift
let request = AudioSpeechRequest(
    model: "tts-1-hd",
    input: "Hello, this is a text-to-speech example.",
    voice: .alloy,
    speed: 1.0
)

let audioData = try await openAI.createSpeech(request)
// Save or play the audio data
```

## See Also

- ``AudioTranscriptionRequest``
- ``AudioSpeechRequest``