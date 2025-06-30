import Foundation
import Testing

@testable import OpenAIChat
@testable import OpenAISwift

@Suite("Structured Output JSON Schema Live Tests")
struct StructuredOutputJsonSchemaLiveTests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey)
    }

    struct SumResult: Decodable {
        let result: Int
    }

    @Test("Chat completion with explicit JSON Schema response format")
    func testJsonSchemaResponse() async throws {
        try requireLiveTests()

        // Build the JSON schema manually
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "result": ["type": "integer"]
            ],
            "required": ["result"],
            "additionalProperties": false
        ]

        let responseFormat = ResponseFormat(
            type: .jsonStructuredOutput,
            jsonStructuredOutput: JSONStructuredOutput(
                name: "sum_response",
                structuredOutput: schema,
                strict: true
            )
        )

        let messages = [
            ChatMessage(
                role: .user,
                content: .text("What is the sum of 2 and 3? Return only the integer result in the 'result' field according to the schema.")
            )
        ]

        // Create explicit request
        let request = ChatRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0,
            maxTokens: 20,
            responseFormat: responseFormat
        )

        let response = try await api.createChatCompletion(request)

        guard let message = response.choices.first?.message,
              case .text(let jsonString) = message.content,
              let data = jsonString.data(using: String.Encoding.utf8)
        else {
            Issue.record("Expected text content with JSON payload")
            return
        }

        let sum = try JSONDecoder().decode(SumResult.self, from: data)
        #expect(sum.result == 5)
    }
} 