import Foundation
import OpenAICore

extension OpenAI {
    /**
     Transcribes audio into the input language.
    
     Creates a transcription of the audio file in the same language as the audio. The Whisper model
     will automatically detect the language if not specified, but providing the language can improve
     accuracy and reduce latency.
    
     ## Example
     ```swift
     let audioData = try Data(contentsOf: audioFileURL)
     let request = TranscriptionRequest(
         file: audioData,
         model: "whisper-1",
         language: "en",
         responseFormat: .verboseJson,
         timestampGranularities: [.word, .segment]
     )
    
     do {
         let response = try await openAI.createTranscription(request)
         print("Transcription: \(response.text)")
    
         // Access word-level timestamps
         response.words?.forEach { word in
             print("\(word.word): \(word.start)s - \(word.end)s")
         }
     } catch {
         print("Transcription failed: \(error)")
     }
     ```
    
     - Parameter request: The transcription request containing the audio file and configuration
     - Returns: A transcription response containing the transcribed text and optional metadata
     - Throws: An error if the transcription fails, the audio format is unsupported, or the API request fails
    
     - Note: Supported audio formats include: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, and webm
     - Important: File uploads are limited to 25 MB
     */
    public func createTranscription(_ request: TranscriptionRequest) async throws
        -> TranscriptionResponse
    {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(request.file)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(request.model)\r\n".data(using: .utf8)!)

        if let language = request.language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        if let prompt = request.prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }

        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(
                    using: .utf8)!)
            body.append("\(responseFormat.rawValue)\r\n".data(using: .utf8)!)
        }

        if let temperature = request.temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(temperature)\r\n".data(using: .utf8)!)
        }

        if let timestampGranularities = request.timestampGranularities {
            for granularity in timestampGranularities {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append(
                    "Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n"
                        .data(using: .utf8)!)
                body.append("\(granularity.rawValue)\r\n".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURL.appendingPathComponent("audio/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(TranscriptionResponse.self, from: data, response: response)
    }

    /**
     Translates audio into English text.
    
     Creates a translation of the audio file into English. The Whisper model will automatically
     detect the source language and translate it to English.
    
     ## Example
     ```swift
     let audioData = try Data(contentsOf: audioFileURL)
     let request = TranslationRequest(
         file: audioData,
         model: "whisper-1",
         prompt: "This is a podcast about technology.",
         responseFormat: .json
     )
    
     do {
         let response = try await openAI.createTranslation(request)
         print("Translation: \(response.text)")
     } catch {
         print("Translation failed: \(error)")
     }
     ```
    
     - Parameter request: The translation request containing the audio file and configuration
     - Returns: A transcription response containing the translated English text
     - Throws: An error if the translation fails, the audio format is unsupported, or the API request fails
    
     - Note: Currently only translation into English is supported
     - Note: Supported audio formats include: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, and webm
     - Important: File uploads are limited to 25 MB
     - Important: The response will always be in English regardless of the input language
     */
    public func createTranslation(_ request: TranslationRequest) async throws
        -> TranscriptionResponse
    {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(request.file)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(request.model)\r\n".data(using: .utf8)!)

        if let prompt = request.prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }

        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(
                    using: .utf8)!)
            body.append("\(responseFormat.rawValue)\r\n".data(using: .utf8)!)
        }

        if let temperature = request.temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(temperature)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURL.appendingPathComponent("audio/translations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(TranscriptionResponse.self, from: data, response: response)
    }
}
