import Foundation
import Testing

@testable import OpenAISwift

@Suite("Model Type Tests")
struct ModelTypeTests {

    @Suite("Chat Models")
    struct ChatModelTests {

        @Test("ChatMessage initialization and encoding")
        func testChatMessage() throws {
            let textMessage = ChatMessage(role: .user, content: .text("Hello"))
            #expect(textMessage.role == .user)
            #expect(textMessage.name == nil)

            if case .text(let content) = textMessage.content {
                #expect(content == "Hello")
            } else {
                Issue.record("Expected text content")
            }

            // Test encoding
            let encoder = JSONEncoder()
            let data = try encoder.encode(textMessage)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            #expect(json?["role"] as? String == "user")
            #expect(json?["content"] as? String == "Hello")
        }

        @Test("ChatMessage with tool calls")
        func testChatMessageWithToolCalls() throws {
            let toolCall = ToolCall(
                id: "call_123",
                type: .function,
                function: FunctionCall(
                    name: "get_weather",
                    arguments: "{\"location\": \"San Francisco\"}"
                )
            )

            let message = ChatMessage(
                role: .assistant,
                content: nil,
                toolCalls: [toolCall]
            )

            #expect(message.role == Role.assistant)
            if let calls = message.toolCalls {
                #expect(calls.count == 1)
                #expect(calls.first?.id == "call_123")
                #expect(calls.first?.function.name == "get_weather")
            }
        }

        @Test("ChatRequest validation")
        func testChatRequest() throws {
            let messages = [
                ChatMessage(role: .system, content: .text("You are helpful")),
                ChatMessage(role: .user, content: .text("Hello")),
            ]

            let request = ChatRequest(
                model: "gpt-4",
                messages: messages,
                temperature: 0.7,
                topP: 0.9,
                n: 2,
                stream: false,
                stop: .array(["\\n", "END"]),
                maxTokens: 100,
                presencePenalty: 0.5,
                frequencyPenalty: 0.3,
                logitBias: ["123": 5],
                user: "test_user"
            )

            #expect(request.model == "gpt-4")
            #expect(request.messages.count == 2)
            #expect(request.temperature == 0.7)
            #expect(request.topP == 0.9)
            #expect(request.n == 2)
            #expect(request.stream == false)
            if case .array(let stops) = request.stop {
                #expect(stops.count == 2)
            }
            #expect(request.maxTokens == 100)
            #expect(request.presencePenalty == 0.5)
            #expect(request.frequencyPenalty == 0.3)
            #expect(request.logitBias?["123"] == 5)
            #expect(request.user == "test_user")
        }

        @Test("ResponseFormat encoding")
        func testResponseFormat() throws {
            let format = ResponseFormat(
                type: .jsonStructuredOutput,
                jsonStructuredOutput: JSONStructuredOutput(
                    name: "test_schema",
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

            #expect(format.type == ResponseFormatType.jsonStructuredOutput)
            #expect(format.jsonStructuredOutput != nil)

            // Test encoding
            let encoder = JSONEncoder()
            let data = try encoder.encode(format)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let jsonDict = json
            #expect(jsonDict?["type"] as? String == "json_schema")
            #expect(jsonDict?["json_schema"] as? [String: Any] != nil)
        }
    }

    @Suite("Embedding Models")
    struct EmbeddingModelTests {

        @Test("EmbeddingRequest with single text")
        func testEmbeddingRequestSingleText() throws {
            let request = EmbeddingRequest(
                input: .string("Test embedding"),
                model: "text-embedding-ada-002",
                encodingFormat: .float,
                dimensions: 1536
            )

            #expect(request.model == "text-embedding-ada-002")
            if case .string(let input) = request.input {
                #expect(input == "Test embedding")
            }
            #expect(request.encodingFormat == .float)
            #expect(request.dimensions == 1536)
        }

        @Test("EmbeddingRequest with array")
        func testEmbeddingRequestArray() throws {
            let texts = ["First", "Second", "Third"]
            let request = EmbeddingRequest(
                input: .array(texts),
                model: "text-embedding-ada-002"
            )

            if case .array(let inputs) = request.input {
                #expect(inputs.count == 3)
                #expect(inputs[0] == "First")
                #expect(inputs[2] == "Third")
            }
        }

        @Test("EmbeddingResponse decoding")
        func testEmbeddingResponse() throws {
            let json = """
                {
                    "object": "list",
                    "data": [
                        {
                            "object": "embedding",
                            "index": 0,
                            "embedding": [0.1, 0.2, 0.3]
                        }
                    ],
                    "model": "text-embedding-ada-002",
                    "usage": {
                        "prompt_tokens": 5,
                        "total_tokens": 5
                    }
                }
                """

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let response = try decoder.decode(
                EmbeddingResponse.self, from: json.data(using: .utf8)!)

            #expect(response.object == "list")
            #expect(response.data.count == 1)
            #expect(response.data.first?.index == 0)
            #expect(response.data.first?.embedding.count == 3)
            #expect(response.model == "text-embedding-ada-002")
            #expect(response.usage.promptTokens == 5)
        }
    }

    @Suite("Image Models")
    struct ImageModelTests {

        @Test("ImageGenerationRequest")
        func testImageGenerationRequest() throws {
            let request = ImageGenerationRequest(
                prompt: "A beautiful sunset",
                model: "dall-e-3",
                n: 2,
                quality: .hd,
                responseFormat: .b64Json,
                size: .size1024x1024,
                style: .vivid,
                user: "test_user"
            )

            #expect(request.prompt == "A beautiful sunset")
            #expect(request.model == "dall-e-3")
            #expect(request.n == 2)
            #expect(request.size == ImageSize.size1024x1024)
            #expect(request.quality == Quality.hd)
            #expect(request.style == Style.vivid)
            #expect(request.responseFormat == ImageResponseFormat.b64Json)
            #expect(request.user == "test_user")
        }

        @Test("ImageSize raw values")
        func testImageSizeRawValues() {
            #expect(ImageSize.size256x256.rawValue == "256x256")
            #expect(ImageSize.size512x512.rawValue == "512x512")
            #expect(ImageSize.size1024x1024.rawValue == "1024x1024")
            #expect(ImageSize.size1792x1024.rawValue == "1792x1024")
            #expect(ImageSize.size1024x1792.rawValue == "1024x1792")
        }

        @Test("ImageResponse decoding")
        func testImageResponse() throws {
            let json = """
                {
                    "created": 1234567890,
                    "data": [
                        {
                            "url": "https://example.com/image.png",
                            "revised_prompt": "A beautiful sunset over the ocean"
                        }
                    ]
                }
                """

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let response = try decoder.decode(ImageResponse.self, from: json.data(using: .utf8)!)

            #expect(response.created == 1_234_567_890)
            #expect(response.data.count == 1)
            #expect(response.data.first?.url == "https://example.com/image.png")
            #expect(response.data.first?.revisedPrompt == "A beautiful sunset over the ocean")
        }
    }

    @Suite("Audio Models")
    struct AudioModelTests {

        @Test("TranscriptionRequest")
        func testTranscriptionRequest() {
            let audioData = Data()
            let request = TranscriptionRequest(
                file: audioData,
                model: "whisper-1",
                language: "en",
                prompt: "This is about AI",
                responseFormat: .json,
                temperature: 0.2
            )

            #expect(request.model == "whisper-1")
            #expect(request.language == "en")
            #expect(request.prompt == "This is about AI")
            #expect(request.responseFormat == .json)
            #expect(request.temperature == 0.2)
        }

        @Test("TextToSpeechRequest")
        func testTextToSpeechRequest() {
            let request = TextToSpeechRequest(
                model: "tts-1-hd",
                input: "Hello, world!",
                voice: .nova,
                responseFormat: .opus,
                speed: 1.5
            )

            #expect(request.model == "tts-1-hd")
            #expect(request.input == "Hello, world!")
            #expect(request.voice == .nova)
            #expect(request.responseFormat == .opus)
            #expect(request.speed == 1.5)
        }

        @Test("Voice raw values")
        func testVoiceRawValues() {
            #expect(Voice.alloy.rawValue == "alloy")
            #expect(Voice.echo.rawValue == "echo")
            #expect(Voice.fable.rawValue == "fable")
            #expect(Voice.onyx.rawValue == "onyx")
            #expect(Voice.nova.rawValue == "nova")
            #expect(Voice.shimmer.rawValue == "shimmer")
        }
    }

    @Suite("Error Models")
    struct ErrorModelTests {

        @Test("ErrorResponse decoding")
        func testErrorResponse() throws {
            let json = """
                {
                    "error": {
                        "message": "Invalid API key",
                        "type": "invalid_request_error",
                        "param": "api_key",
                        "code": "invalid_api_key"
                    }
                }
                """

            let response = try JSONDecoder().decode(
                ErrorResponse.self, from: json.data(using: .utf8)!)

            #expect(response.error.message == "Invalid API key")
            #expect(response.error.type == "invalid_request_error")
            #expect(response.error.param == "api_key")
            #expect(response.error.code == "invalid_api_key")
        }

        @Test("OpenAIError types")
        func testOpenAIErrorTypes() {
            let apiError = OpenAIError.apiError(
                ErrorResponse(
                    error: APIError(
                        message: "Test error",
                        type: "test_error",
                        param: nil,
                        code: "test"
                    )
                ))

            if case .apiError(let errorResponse) = apiError {
                #expect(errorResponse.error.message == "Test error")
            }
        }
    }

    @Suite("Tool and Function Models")
    struct ToolFunctionTests {

        @Test("Function definition")
        func testFunctionDefinition() throws {
            let function = FunctionDefinition(
                name: "calculate",
                description: "Perform calculations",
                parameters: [
                    "type": "object",
                    "properties": [
                        "expression": [
                            "type": "string",
                            "description": "Math expression",
                        ]
                    ],
                    "required": ["expression"],
                ]
            )

            #expect(function.name == "calculate")
            #expect(function.description == "Perform calculations")
            #expect(function.parameters?["type"] as? String == "object")

            // Test encoding
            let encoder = JSONEncoder()
            let data = try encoder.encode(function)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            #expect(json?["name"] as? String == "calculate")
            #expect(json?["description"] as? String == "Perform calculations")
        }

        @Test("Tool choice encoding")
        func testToolChoice() throws {
            let encoder = JSONEncoder()

            // Test none
            let none = ToolChoice.none
            let noneData = try encoder.encode(none)
            #expect(String(data: noneData, encoding: .utf8) == "\"none\"")

            // Test auto
            let auto = ToolChoice.auto
            let autoData = try encoder.encode(auto)
            #expect(String(data: autoData, encoding: .utf8) == "\"auto\"")

            // Test function
            let function = ToolChoice.function(name: "my_function")
            let functionData = try encoder.encode(function)
            let functionJson =
                try JSONSerialization.jsonObject(with: functionData) as? [String: Any]
            #expect(functionJson?["type"] as? String == "function")
            #expect((functionJson?["function"] as? [String: String])?["name"] == "my_function")
        }
    }
}