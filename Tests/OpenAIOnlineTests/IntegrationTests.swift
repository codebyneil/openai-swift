import Foundation
import Testing

@testable import OpenAISwift

@Suite("Integration Tests", .timeLimit(.minutes(5)))
struct IntegrationTests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey)
    }

    @Test("Complete chat workflow with tools")
    func testCompleteChatWorkflow() async throws {
        try requireLiveTests()
        // 1. Start with a system message
        var messages: [ChatMessage] = [
            ChatMessage(
                role: .system,
                content: .text(
                    "You are a helpful assistant with access to weather and calculation tools.")
            )
        ]

        // 2. Define available tools
        let weatherFunction = FunctionDefinition(
            name: "get_weather",
            description: "Get the current weather in a location",
            parameters: [
                "type": "object",
                "properties": [
                    "location": ["type": "string"],
                    "unit": ["type": "string", "enum": ["celsius", "fahrenheit"]],
                ],
                "required": ["location"],
            ]
        )

        let calculateFunction = FunctionDefinition(
            name: "calculate",
            description: "Perform mathematical calculations",
            parameters: [
                "type": "object",
                "properties": [
                    "expression": ["type": "string"]
                ],
                "required": ["expression"],
            ]
        )

        // 3. User asks about weather
        messages.append(
            ChatMessage(
                role: .user,
                content: .text("What's the weather in San Francisco and New York?")
            ))

        let request1 = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages,
            tools: [ChatTool(function: weatherFunction), ChatTool(function: calculateFunction)],
            toolChoice: .required
        )

        let response1 = try await api.createChatCompletion(request1)

        // 4. Assistant should call weather function
        guard let choice1 = response1.choices.first,
            let toolCalls = choice1.message.toolCalls
        else {
            Issue.record("Expected tool calls")
            return
        }

        messages.append(choice1.message)

        // 5. Simulate tool responses
        for toolCall in toolCalls {
            let weatherData = """
                {"temperature": 72, "condition": "sunny", "humidity": 65}
                """

            messages.append(
                ChatMessage(
                    role: .tool,
                    content: .text(weatherData),
                    toolCallId: toolCall.id
                ))
        }

        // 6. Get final response
        let request2 = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages
        )

        let response2 = try await api.createChatCompletion(request2)

        #expect(response2.choices.count > 0)
        if let finalChoice = response2.choices.first,
            case .text(let content) = finalChoice.message.content
        {
            #expect(content.contains("San Francisco") || content.contains("New York"))
            #expect(content.contains("72") || content.contains("sunny"))
        }
    }

    @Test("Embedding similarity search")
    func testEmbeddingSimilaritySearch() async throws {
        try requireLiveTests()
        // Create embeddings for a set of documents
        let documents = [
            "The quick brown fox jumps over the lazy dog",
            "OpenAI creates artificial intelligence systems",
            "Swift is a powerful programming language",
            "The weather today is sunny and warm",
            "Machine learning models can understand text",
        ]

        // Generate embeddings for documents
        let docRequest = EmbeddingRequest(
            input: .array(documents),
            model: TestConstants.Models.embedding
        )

        let docResponse = try await api.createEmbedding(docRequest)
        #expect(docResponse.data.count == documents.count)

        // Generate embedding for query
        let query = "AI and machine learning"
        let queryRequest = EmbeddingRequest(
            input: .string(query),
            model: TestConstants.Models.embedding
        )

        let queryResponse = try await api.createEmbedding(queryRequest)
        guard let queryEmbedding = queryResponse.data.first?.embedding else {
            Issue.record("No query embedding")
            return
        }

        // Calculate cosine similarities
        var similarities: [(index: Int, score: Double)] = []

        for (index, docEmbedding) in docResponse.data.enumerated() {
            let similarity = cosineSimilarity(queryEmbedding, docEmbedding.embedding)
            similarities.append((index: index, score: similarity))
        }

        // Sort by similarity
        similarities.sort { $0.score > $1.score }

        // The most similar documents should be about AI/ML
        let topIndices = similarities.prefix(2).map { $0.index }
        #expect(topIndices.contains(1) || topIndices.contains(4))  // AI and ML documents
    }

    @Test("Multi-turn conversation with context")
    func testMultiTurnConversation() async throws {
        try requireLiveTests()
        var messages: [ChatMessage] = [
            ChatMessage(
                role: .system,
                content: .text("You are a helpful math tutor. Keep track of previous calculations.")
            )
        ]

        // Turn 1: Ask for calculation
        messages.append(
            ChatMessage(
                role: .user,
                content: .text("What is 15 * 8?")
            ))

        let response1 = try await api.createChatCompletion(
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0
            )
        )

        let answer1 = response1.choices.first!.message
        messages.append(answer1)

        if case .text(let content) = answer1.content {
            #expect(content.contains("120"))
        }

        // Turn 2: Reference previous calculation
        messages.append(
            ChatMessage(
                role: .user,
                content: .text("Now divide that result by 4")
            ))

        let response2 = try await api.createChatCompletion(
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0
            )
        )

        let answer2 = response2.choices.first!.message
        messages.append(answer2)

        if case .text(let content) = answer2.content {
            #expect(content.contains("30"))
        }

        // Turn 3: Another reference
        messages.append(
            ChatMessage(
                role: .user,
                content: .text("What was our first calculation again?")
            ))

        let response3 = try await api.createChatCompletion(
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: messages,
                temperature: 0.0
            )
        )

        if case .text(let content) = response3.choices.first!.message.content {
            #expect(content.contains("15") && content.contains("8") && content.contains("120"))
        }
    }

    @Test("Streaming with token counting")
    func testStreamingTokenCounting() async throws {
        try requireLiveTests()
        let prompt = "Write a haiku about programming"
        let messages = [
            ChatMessage(role: .user, content: .text(prompt))
        ]

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages,
            temperature: 0.7,
            stream: true
        )

        let stream = try await api.createChatCompletionStream(request)

        var fullContent = ""
        var chunkCount = 0

        for try await chunk in stream {
            chunkCount += 1

            if let delta = chunk.choices.first?.delta,
                let content = delta.content
            {
                fullContent += content
            }
        }

        #expect(chunkCount > 5)  // Should receive multiple chunks
        #expect(fullContent.count > 20)  // Should have meaningful content

        // Verify it's roughly haiku-like (3 lines)
        let lines = fullContent.split(separator: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 3)
    }

    @Test("Error recovery and retry")
    func testErrorRecoveryAndRetry() async throws {
        try requireLiveTests()
        // Test with invalid model to trigger error
        let messages = [
            ChatMessage(role: .user, content: .text("Hello"))
        ]

        let invalidRequest = ChatRequest(
            model: "invalid-model-xyz",
            messages: messages
        )

        do {
            _ = try await api.createChatCompletion(invalidRequest)
            Issue.record("Should have thrown an error")
        } catch {
            // Expected error
            #expect(error is OpenAIError)
        }

        // Now try with valid model
        let validRequest = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages,
            maxTokens: 10
        )

        let response = try await api.createChatCompletion(validRequest)
        #expect(response.choices.count > 0)
    }

    // Helper function for cosine similarity
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }

        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
}
