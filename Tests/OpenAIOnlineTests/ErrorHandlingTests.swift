import Foundation
import Testing

@testable import OpenAISwift

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

    init() {
    }

    @Test("Invalid API key error")
    func testInvalidAPIKey() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: "invalid-key-12345")

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [ChatMessage(role: .user, content: .text("Hello"))]
        )

        do {
            _ = try await api.createChatCompletion(request)
            Issue.record("Should have thrown an error for invalid API key")
        } catch let error as OpenAIError {
            if case .apiError(let detail) = error {
                #expect(
                    detail.error.code == "invalid_api_key"
                        || detail.error.type == "invalid_request_error")
            } else {
                Issue.record("Expected API error type")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Invalid model error")
    func testInvalidModel() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: TestConstants.apiKey)

        let request = ChatRequest(
            model: TestConstants.Models.nonExistentModel,
            messages: [ChatMessage(role: .user, content: .text("Hello"))]
        )

        do {
            _ = try await api.createChatCompletion(request)
            Issue.record("Should have thrown an error for invalid model")
        } catch {
            #expect(error is OpenAIError)
        }
    }

    @Test("Empty messages error")
    func testEmptyMessages() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: TestConstants.apiKey)

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: []
        )

        do {
            _ = try await api.createChatCompletion(request)
            Issue.record("Should have thrown an error for empty messages")
        } catch {
            #expect(error is OpenAIError)
        }
    }

    @Test("Token limit exceeded")
    func testTokenLimitExceeded() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: TestConstants.apiKey)

        // Create a very long message that exceeds token limits
        let longText = String(repeating: "This is a very long text. ", count: 10000)

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [ChatMessage(role: .user, content: .text(longText))],
            maxTokens: 10
        )

        do {
            _ = try await api.createChatCompletion(request)
            Issue.record("Should have thrown an error for token limit")
        } catch {
            #expect(error is OpenAIError)
        }
    }

    @Test("Invalid image size")
    func testInvalidImageSize() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: TestConstants.apiKey)

        // Test with DALL-E 3 specific size on DALL-E 2
        let request = ImageGenerationRequest(
            prompt: "A test image",
            model: TestConstants.Models.dallE2,
            size: .size1792x1024  // This size is only for DALL-E 3
        )

        do {
            _ = try await api.createImage(request)
            Issue.record("Should have thrown an error for invalid size")
        } catch {
            #expect(error is OpenAIError)
        }
    }

    @Test("Network timeout simulation")
    func testNetworkTimeout() async throws {
        try requireLiveTests()
        // Create API with very short timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 0.001  // 1ms timeout
        let session = URLSession(configuration: configuration)

        let api = OpenAI(
            apiKey: TestConstants.apiKey,
            organization: nil,
            session: session
        )

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [ChatMessage(role: .user, content: .text("Hello"))]
        )

        do {
            _ = try await api.createChatCompletion(request)
            Issue.record("Should have timed out")
        } catch {
            // Should be a network error
            // URLError is expected since OpenAIError doesn't have networkError case
            #expect(error is URLError || error is OpenAIError)
        }
    }

    @Test("Malformed JSON response")
    func testMalformedJSONResponse() throws {
        let malformedJSON = "{ invalid json }"

        do {
            _ = try JSONDecoder().decode(ChatResponse.self, from: malformedJSON.data(using: .utf8)!)
            Issue.record("Should have thrown decoding error")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("Missing required fields")
    func testMissingRequiredFields() throws {
        let incompleteJSON = """
            {
                "id": "test-id",
                "object": "chat.completion"
            }
            """

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            _ = try decoder.decode(ChatResponse.self, from: incompleteJSON.data(using: .utf8)!)
            Issue.record("Should have thrown decoding error for missing fields")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("Rate limit error simulation")
    func testRateLimitError() throws {
        let rateLimitJSON = """
            {
                "error": {
                    "message": "Rate limit exceeded",
                    "type": "rate_limit_error",
                    "param": null,
                    "code": "rate_limit_exceeded"
                }
            }
            """

        let errorResponse = try JSONDecoder().decode(
            ErrorResponse.self, from: rateLimitJSON.data(using: .utf8)!)

        #expect(errorResponse.error.type == "rate_limit_error")
        #expect(errorResponse.error.code == "rate_limit_exceeded")
    }

    @Test("Invalid function call format")
    func testInvalidFunctionCall() async throws {
        try requireLiveTests()
        let api = OpenAI(apiKey: TestConstants.apiKey)

        // Create function with invalid parameter schema
        let invalidFunction = FunctionDefinition(
            name: "invalid_function",
            description: "Test function",
            parameters: [
                "invalid": "schema"
            ]
        )

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [ChatMessage(role: .user, content: .text("Use the function"))],
            tools: [ChatTool(function: invalidFunction)]
        )

        do {
            _ = try await api.createChatCompletion(request)
            // API might accept it but return an error in usage
        } catch {
            #expect(error is OpenAIError)
        }
    }
}
