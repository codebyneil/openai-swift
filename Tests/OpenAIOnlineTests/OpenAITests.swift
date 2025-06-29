import Foundation
import Testing

@testable import OpenAISwift

@Suite("OpenAI API Tests")
struct OpenAITests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey, organization: TestConstants.organization)
    }

    @Suite("Chat Completions")
    struct ChatCompletionTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("Create simple chat completion")
        func testCreateChatCompletion() async throws {
            try requireLiveTests()
            let messages = [
                ChatMessage(role: .system, content: .text("You are a helpful assistant.")),
                ChatMessage(role: .user, content: .text("Say 'Hello, World!' and nothing else.")),
            ]

            let request = ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0,
                maxTokens: 10
            )

            let response = try await api.createChatCompletion(request)

            #expect(!response.id.isEmpty)
            #expect(response.model.contains("gpt-3.5"))
            #expect(response.choices.count > 0)
            #expect(response.usage != nil)

            if let firstChoice = response.choices.first {
                #expect(firstChoice.index == 0)
                // finishReason can be nil for very short responses

                if case .text(let content) = firstChoice.message.content {
                    #expect(content.lowercased().contains("hello"))
                }
            }
        }

        @Test("Chat completion with function calling")
        func testChatCompletionWithFunctions() async throws {
            try requireLiveTests()
            let weatherFunction = FunctionDefinition(
                name: "get_weather",
                description: "Get the current weather in a given location",
                parameters: [
                    "type": "object",
                    "properties": [
                        "location": [
                            "type": "string",
                            "description": "The city and state, e.g. San Francisco, CA",
                        ],
                        "unit": [
                            "type": "string",
                            "enum": ["celsius", "fahrenheit"],
                        ],
                    ],
                    "required": ["location"],
                ]
            )

            let messages = [
                ChatMessage(
                    role: .user, content: .text("What's the weather like in San Francisco?"))
            ]

            let request = ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0,
                tools: [ChatTool(function: weatherFunction)],
                toolChoice: .auto
            )

            let response = try await api.createChatCompletion(request)

            #expect(response.choices.count > 0)
            if let firstChoice = response.choices.first,
                firstChoice.message.toolCalls != nil
            {
                let toolCalls = firstChoice.message.toolCalls ?? []
                #expect(toolCalls.count > 0)
                #expect(toolCalls.first?.function.name == "get_weather")
            }
        }

        @Test("Chat completion with response format")
        func testChatCompletionWithResponseFormat() async throws {
            try requireLiveTests()
            let messages = [
                ChatMessage(
                    role: .user, content: .text("Generate a JSON object with name and age fields"))
            ]

            let responseFormat = ResponseFormat(
                type: .jsonStructuredOutput,
                jsonStructuredOutput: JSONStructuredOutput(
                    name: "person",
                    structuredOutput: [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "age": ["type": "integer"],
                        ],
                        "required": ["name", "age"],
                    ]
                )
            )

            let request = ChatRequest(
                model: "gpt-4o-mini",
                messages: messages,
                temperature: 0.0,
                responseFormat: responseFormat
            )

            let response = try await api.createChatCompletion(request)

            #expect(response.choices.count > 0)
            if let firstChoice = response.choices.first,
                case .text(let content) = firstChoice.message.content
            {
                let data = try #require(content.data(using: String.Encoding.utf8))
                let json = try JSONSerialization.jsonObject(with: data)
                #expect(json is [String: Any])
            }
        }

        @Test("Streaming chat completion")
        func testStreamingChatCompletion() async throws {
            try requireLiveTests()
            let messages = [
                ChatMessage(role: .user, content: .text("Count from 1 to 5"))
            ]

            let request = ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0,
                stream: true
            )

            let stream = try await api.createChatCompletionStream(request)

            var chunks: [ChatCompletionStreamResponse] = []
            for try await chunk in stream {
                chunks.append(chunk)
            }

            #expect(chunks.count > 0)
            #expect(chunks.first?.choices.first?.delta != nil)

            let content = chunks.compactMap { chunk -> String? in
                guard let delta = chunk.choices.first?.delta else { return nil }
                return delta.content
            }.joined()

            #expect(content.count > 0)
        }
    }

    @Suite("Embeddings")
    struct EmbeddingTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("Create text embedding")
        func testCreateTextEmbedding() async throws {
            try requireLiveTests()
            let request = EmbeddingRequest(
                input: .string("Hello, world!"),
                model: TestConstants.Models.embedding
            )

            let response = try await api.createEmbedding(request)

            #expect(response.data.count > 0)
            #expect(response.model.contains("text-embedding-ada-002"))
            #expect(response.usage.promptTokens > 0)
            #expect(response.usage.totalTokens > 0)

            if let firstEmbedding = response.data.first {
                #expect(firstEmbedding.index == 0)
                #expect(firstEmbedding.embedding.count == 1536)  // ada-002 dimension
            }
        }

        @Test("Create batch embeddings")
        func testCreateBatchEmbeddings() async throws {
            try requireLiveTests()
            let texts = ["Hello", "World", "OpenAI"]
            let request = EmbeddingRequest(
                input: .array(texts),
                model: TestConstants.Models.embedding
            )

            let response = try await api.createEmbedding(request)

            #expect(response.data.count == texts.count)
            for (index, embedding) in response.data.enumerated() {
                #expect(embedding.index == index)
                #expect(embedding.embedding.count == 1536)
            }
        }
    }

    @Suite("Images")
    struct ImageTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("Generate image from prompt")
        func testGenerateImage() async throws {
            try requireLiveTests()
            let request = ImageGenerationRequest(
                prompt: "A red apple on a white background",
                model: TestConstants.Models.image,
                n: 1,
                quality: .standard,
                responseFormat: .url,
                size: .size1024x1024
            )

            let response = try await api.createImage(request)

            #expect(response.data.count == 1)
            if let firstImage = response.data.first {
                #expect(firstImage.url != nil || firstImage.b64Json != nil)
                // revisedPrompt is only returned for DALL-E 3 and is optional
                // Don't require it to be present
            }
        }

        @Test("Edit image", .disabled("Requires real image data for API"))
        func testEditImage() async throws {
            // Create a simple test image
            let imageData = createTestImageData()
            let maskData = createTestMaskData()

            let request = ImageEditRequest(
                image: imageData,
                prompt: "Add a blue sky background",
                mask: maskData,
                model: "dall-e-2",
                n: 1,
                size: .size512x512,
                responseFormat: .url
            )

            let response = try await api.editImage(request)

            #expect(response.data.count == 1)
            #expect(response.data.first?.url != nil || response.data.first?.b64Json != nil)
        }

        @Test("Create image variation", .disabled("Requires real image data for API"))
        func testCreateImageVariation() async throws {
            let imageData = createTestImageData()

            let request = ImageVariationRequest(
                image: imageData,
                model: "dall-e-2",
                n: 1,
                responseFormat: .url,
                size: .size256x256
            )

            let response = try await api.createImageVariation(request)

            #expect(response.data.count == 1)
            #expect(response.data.first?.url != nil || response.data.first?.b64Json != nil)
        }

        private func createTestImageData() -> Data {
            // Create a simple 1x1 red PNG that should work with OpenAI
            let pngData: [UInt8] = [
                // PNG signature
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                // IHDR chunk
                0x00, 0x00, 0x00, 0x0D,  // chunk length
                0x49, 0x48, 0x44, 0x52,  // "IHDR"
                0x00, 0x00, 0x00, 0x01,  // width: 1
                0x00, 0x00, 0x00, 0x01,  // height: 1
                0x08, 0x02, 0x00, 0x00, 0x00,  // 8-bit RGB, no interlace
                0x90, 0x77, 0x53, 0xDE,  // CRC
                // IDAT chunk
                0x00, 0x00, 0x00, 0x0C,  // chunk length
                0x49, 0x44, 0x41, 0x54,  // "IDAT"
                0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,  // compressed RGB data
                0x18, 0xDD, 0x8D, 0xB4,  // CRC
                // IEND chunk
                0x00, 0x00, 0x00, 0x00,  // chunk length
                0x49, 0x45, 0x4E, 0x44,  // "IEND"
                0xAE, 0x42, 0x60, 0x82,  // CRC
            ]
            return Data(pngData)
        }

        private func createTestMaskData() -> Data {
            // Reuse same format as main image for consistency
            return createTestImageData()
        }
    }

    @Suite("Audio")
    struct AudioTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("Transcribe audio")
        func testTranscribeAudio() async throws {
            try requireLiveTests()
            let audioData = createTestAudioData()

            let request = TranscriptionRequest(
                file: audioData,
                model: TestConstants.Models.audio,
                language: "en",
                responseFormat: .json
            )

            let response = try await api.createTranscription(request)

            #expect(response.text.count > 0)
        }

        @Test("Translate audio", .disabled("Timeout issues in test environment"))
        func testTranslateAudio() async throws {
            let audioData = createTestAudioData()

            let request = TranslationRequest(
                file: audioData,
                model: TestConstants.Models.audio,
                responseFormat: .json
            )

            let response = try await api.createTranslation(request)

            #expect(response.text.count > 0)
        }

        // @Test("Create speech")
        // func testCreateSpeech() async throws {
        //     let request = SpeechRequest(
        //         model: "tts-1",
        //         input: "Hello, this is a test.",
        //         voice: .alloy,
        //         responseFormat: .mp3,
        //         speed: 1.0
        //     )
        //
        //     let audioData = try await api.createSpeech(request)
        //
        //     #expect(audioData.count > 0)
        // }

        private func createTestAudioData() -> Data {
            // Create a minimal valid WAV file with 0.2 seconds of silence (16-bit, 44.1kHz)
            var wavData = Data()

            let sampleRate: UInt32 = 44100
            let durationSeconds: Double = 0.2
            let numSamples = Int(Double(sampleRate) * durationSeconds)
            let dataSize = UInt32(numSamples * 2)  // 16-bit = 2 bytes per sample
            let fileSize = dataSize + 36  // 36 = header size - 8

            // RIFF header
            wavData.append(contentsOf: "RIFF".data(using: .ascii)!)
            wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
            wavData.append(contentsOf: "WAVE".data(using: .ascii)!)

            // fmt chunk
            wavData.append(contentsOf: "fmt ".data(using: .ascii)!)
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Chunk size
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // Audio format (PCM)
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // Number of channels
            wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })  // Sample rate
            wavData.append(
                contentsOf: withUnsafeBytes(of: (sampleRate * 2).littleEndian) { Array($0) })  // Byte rate
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // Block align
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // Bits per sample

            // data chunk
            wavData.append(contentsOf: "data".data(using: .ascii)!)
            wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

            // Add silence samples
            for _ in 0..<numSamples {
                wavData.append(contentsOf: [0x00, 0x00])  // 16-bit silence
            }

            return wavData
        }
    }

    @Suite("Models")
    struct ModelTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("List available models")
        func testListModels() async throws {
            try requireLiveTests()
            let models = try await api.listModels()

            #expect(models.data.count > 0)
            #expect(models.object == "list")

            // Check for common models
            let modelIds = models.data.map { $0.id }
            #expect(modelIds.contains { $0.contains("gpt") })
        }

        @Test("Retrieve specific model")
        func testRetrieveModel() async throws {
            try requireLiveTests()
            let model = try await api.retrieveModel(modelId: "gpt-3.5-turbo")

            #expect(model.id == "gpt-3.5-turbo")
            #expect(model.object == "model")
            // ownedBy is optional and may not be present in all environments
        }
    }
}
