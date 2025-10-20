import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

// Test models for live API tests
struct WeatherInfo: Decodable {
    let temperature: Double
    let condition: String
    let humidity: Int
}

struct AnalysisResult: StructuredOutputConvertible, Decodable {
    let sentiment: String
    let confidence: Double
    let keywords: [String]

    static var structuredOutputName: String { "AnalysisResult" }
    static var structuredOutputDescription: String? {
        "Text analysis result with sentiment and keywords"
    }

    static func generateStructuredOutput() -> [String: Any] {
        return [
            "type": "object",
            "description": structuredOutputDescription ?? "",
            "properties": [
                "sentiment": [
                    "type": "string",
                    "enum": ["positive", "negative", "neutral"],
                ],
                "confidence": [
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                ],
                "keywords": [
                    "type": "array",
                    "items": ["type": "string"],
                    "minItems": 1,
                    "maxItems": 5,
                ],
            ],
            "required": ["sentiment", "confidence", "keywords"],
        ]
    }
}

struct ComplexResponse: Decodable {
    struct Person: Decodable {
        let name: String
        let age: Int
        let email: String?
    }

    struct Address: Decodable {
        let street: String
        let city: String
        let country: String
    }

    let person: Person
    let address: Address
    let tags: [String]
}

@Suite("Structured Output Live Tests")
struct StructuredOutputLiveTests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey)
    }

    @Test("Create chat completion with simple Decodable type")
    func testSimpleDecodableResponse() async throws {
        try requireLiveTests()
        let messages = [
            ChatMessage(
                role: .system,
                content: .text(
                    "You are a weather API. Always respond with JSON containing temperature (number), condition (string), and humidity (integer percentage)."
                )
            ),
            ChatMessage(
                role: .user,
                content: .text("What's the weather like in San Francisco today?")
            ),
        ]

        let weather = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: WeatherInfo.self,
            temperature: 0.0
        )

        #expect(weather.temperature > -50 && weather.temperature < 150)
        #expect(!weather.condition.isEmpty)
        #expect(weather.humidity >= 0 && weather.humidity <= 100)
    }

    @Test("Create chat completion with StructuredOutputConvertible type")
    func testStructuredOutputConvertibleResponse() async throws {
        try requireLiveTests()
        let messages = [
            ChatMessage(
                role: .user,
                content: .text(
                    "Analyze the sentiment of this text: 'I absolutely love this new feature! It's amazing and works perfectly.'"
                )
            )
        ]

        let analysis = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: AnalysisResult.self,
            temperature: 0.0
        )

        #expect(["positive", "negative", "neutral"].contains(analysis.sentiment))
        #expect(analysis.confidence >= 0 && analysis.confidence <= 1)
        #expect(analysis.keywords.count >= 1 && analysis.keywords.count <= 5)
        #expect(
            analysis.keywords.contains {
                $0.lowercased().contains("love") || $0.lowercased().contains("amazing")
            })
    }

    @Test("Create chat completion with nested structures")
    func testNestedStructureResponse() async throws {
        try requireLiveTests()
        let messages = [
            ChatMessage(
                role: .system,
                content: .text(
                    "You are a data generator. Always respond with JSON containing person (name, age, optional email), address (street, city, country), and tags array."
                )
            ),
            ChatMessage(
                role: .user,
                content: .text(
                    "Generate sample data for a software developer living in Silicon Valley.")
            ),
        ]

        let response = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: ComplexResponse.self,
            temperature: 0.7,
            maxTokens: 200
        )

        #expect(!response.person.name.isEmpty)
        #expect(response.person.age > 0 && response.person.age < 150)
        #expect(!response.address.city.isEmpty)
        #expect(!response.address.country.isEmpty)
        #expect(response.tags.count > 0)
    }

    @Test("Structured chat request builder")
    func testStructuredChatRequestBuilder() async throws {
        try requireLiveTests()
        struct QuizAnswer: Decodable {
            let answer: String
            let explanation: String
            let isCorrect: Bool
        }

        let messages = [
            ChatMessage(
                role: .user,
                content: .text(
                    "Is the Earth flat? Answer with a JSON object containing answer (yes/no), explanation (string), and isCorrect (boolean)."
                )
            )
        ]

        let request = StructuredChatRequest(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: QuizAnswer.self,
            temperature: 0.0,
            strict: true
        )

        let result = try await request.execute(with: api)

        #expect(result.answer.lowercased() == "no")
        #expect(!result.explanation.isEmpty)
        #expect(result.isCorrect == false)
    }

    @Test("Error handling for invalid schema")
    func testInvalidSchemaError() async throws {
        try requireLiveTests()
        struct InvalidType: Decodable {
            let value: String
        }

        let messages = [
            ChatMessage(
                role: .user,
                content: .text("Return a number")
            )
        ]

        do {
            _ = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                responseType: InvalidType.self,
                temperature: 0.0
            )
            Issue.record("Expected decoding error")
        } catch {
            // Expected to fail if API returns a number but we expect a string
            #expect(error is OpenAIError || error is DecodingError)
        }
    }

    @Test(
        "Streaming with structured output",
        .disabled("Structured output not supported with streaming"))
    func testStreamingStructuredOutput() async throws {
        // This test documents that structured output is not currently supported with streaming
        // It's included to ensure we remember this limitation
    }

    @Test("Array response type")
    func testArrayResponseType() async throws {
        try requireLiveTests()
        struct ListItem: Decodable {
            let id: Int
            let name: String
        }

        struct ListResponse: Decodable {
            let items: [ListItem]
        }

        let messages = [
            ChatMessage(
                role: .user,
                content: .text(
                    "Generate a JSON object with an 'items' array containing 3 objects, each with an id (integer) and name (string) field. Make them programming languages."
                )
            )
        ]

        let response = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: ListResponse.self,
            temperature: 0.0
        )

        #expect(response.items.count == 3)
        for (index, item) in response.items.enumerated() {
            #expect(item.id > 0)
            #expect(!item.name.isEmpty)
        }
    }

    @Test("Enum in response")
    func testEnumResponse() async throws {
        try requireLiveTests()
        struct StatusResponse: Decodable {
            enum Status: String, Decodable {
                case pending
                case processing
                case completed
                case failed
            }

            let status: Status
            let message: String
        }

        let messages = [
            ChatMessage(
                role: .user,
                content: .text(
                    "Return a JSON with status (one of: pending, processing, completed, failed) and message. The task is completed successfully."
                )
            )
        ]

        let response = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: StatusResponse.self,
            temperature: 0.0
        )

        #expect(response.status == .completed)
        #expect(!response.message.isEmpty)
    }

    @Test("Date formatting in response")
    func testDateResponse() async throws {
        try requireLiveTests()
        struct EventInfo: Decodable {
            let name: String
            let date: String  // We use String because Date decoding requires specific format
            let duration: Int
        }

        let messages = [
            ChatMessage(
                role: .user,
                content: .text(
                    "Create an event JSON with name (string), date (ISO 8601 string like '2024-01-15T10:30:00Z'), and duration in minutes (integer). Make it a tech conference."
                )
            )
        ]

        let event = try await api.createChatCompletion(
            model: "gpt-4o-mini",
            messages: messages,
            responseType: EventInfo.self,
            temperature: 0.0
        )

        #expect(!event.name.isEmpty)
        #expect(event.date.contains("T"))  // Basic check for ISO format
        #expect(event.duration > 0)
    }
}
