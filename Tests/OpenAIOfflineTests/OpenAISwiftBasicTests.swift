import Foundation
import Testing

@testable import OpenAISwift

@Suite("OpenAI Swift Basic Tests")
struct OpenAISwiftBasicTests {

    @Test("ChatMessage initialization")
    func testChatMessageInitialization() {
        let message = ChatMessage(
            role: .user,
            content: .text("Hello, world!")
        )

        #expect(message.role == .user)
        if case .text(let content) = message.content {
            #expect(content == "Hello, world!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("ChatRequest initialization")
    func testChatRequestInitialization() {
        let messages = [
            ChatMessage(role: .system, content: .text("You are a helpful assistant.")),
            ChatMessage(role: .user, content: .text("Hello!")),
        ]

        let request = ChatRequest(
            model: "gpt-4",
            messages: messages,
            temperature: 0.7,
            maxTokens: 100
        )

        #expect(request.model == "gpt-4")
        #expect(request.messages.count == 2)
        #expect(request.temperature == 0.7)
        #expect(request.maxTokens == 100)
    }

    @Test("ErrorResponse decoding")
    func testErrorResponseDecoding() throws {
        let json = """
            {
                "error": {
                    "message": "Invalid API key",
                    "type": "invalid_request_error",
                    "param": null,
                    "code": "invalid_api_key"
                }
            }
            """

        let data = json.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)

        #expect(errorResponse.error.message == "Invalid API key")
        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.code == "invalid_api_key")
    }

    @Test("ImageSize raw values")
    func testImageSizeRawValues() {
        #expect(ImageSize.size256x256.rawValue == "256x256")
        #expect(ImageSize.size512x512.rawValue == "512x512")
        #expect(ImageSize.size1024x1024.rawValue == "1024x1024")
        #expect(ImageSize.size1792x1024.rawValue == "1792x1024")
        #expect(ImageSize.size1024x1792.rawValue == "1024x1792")
    }

    @Test("EmbeddingRequest initialization")
    func testEmbeddingRequestInitialization() {
        let request = EmbeddingRequest(
            input: .string("Test embedding"),
            model: "text-embedding-ada-002"
        )

        #expect(request.model == "text-embedding-ada-002")
        if case .string(let input) = request.input {
            #expect(input == "Test embedding")
        } else {
            Issue.record("Expected text input")
        }
    }

    @Test("ToolChoice encoding")
    func testToolChoiceEncoding() throws {
        let encoder = JSONEncoder()

        let noneChoice = ToolChoice.none
        let noneData = try encoder.encode(noneChoice)
        let noneString = String(data: noneData, encoding: .utf8)
        #expect(noneString == "\"none\"")

        let autoChoice = ToolChoice.auto
        let autoData = try encoder.encode(autoChoice)
        let autoString = String(data: autoData, encoding: .utf8)
        #expect(autoString == "\"auto\"")

        let functionChoice = ToolChoice.function(name: "test_function")
        let functionData = try encoder.encode(functionChoice)
        let functionString = String(data: functionData, encoding: .utf8)
        #expect(functionString?.contains("test_function") ?? false)
    }
}