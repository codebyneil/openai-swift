import Foundation
import Testing

@testable import OpenAISwift

@Suite("OpenAI Actor Tests")
struct OpenAIActorTests {
    let actor: OpenAIActor

    init() {
        self.actor = OpenAIActor(
            apiKey: TestConstants.apiKey,
            organization: TestConstants.organization,
            maxRetries: 3,
            retryDelay: 0.5,
            maxRequestsPerMinute: 60
        )
    }

    @Test("Actor initialization")
    func testActorInitialization() async {
        let customActor = OpenAIActor(
            apiKey: "test-key",
            organization: "test-org",
            maxRetries: 5,
            retryDelay: 2.0,
            maxRequestsPerMinute: 30
        )

        // The actor is initialized - we can't directly test private properties
        // but we can verify it handles requests
        await #expect(customActor.maxRetries == 5)
    }

    @Test("Create chat completion through actor")
    func testCreateChatCompletion() async throws {
        try requireLiveTests()
        let messages = [
            ChatMessage(role: .user, content: .text("Say 'test' and nothing else"))
        ]

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages,
            temperature: 0.0,
            maxTokens: 10
        )

        let response = try await actor.createChatCompletion(request)

        #expect(!response.id.isEmpty)
        #expect(response.choices.count > 0)
        #expect(response.usage != nil)
    }

    @Test("Create streaming chat completion through actor")
    func testStreamingChatCompletion() async throws {
        try requireLiveTests()
        let messages = [
            ChatMessage(role: .user, content: .text("Count from 1 to 3"))
        ]

        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: messages,
            temperature: 0.0,
            stream: true
        )

        let stream = try await actor.createChatCompletionStream(request)

        var chunks: [ChatCompletionStreamResponse] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks.count > 0)
    }

    @Test("Create embedding through actor")
    func testCreateEmbedding() async throws {
        try requireLiveTests()
        let request = EmbeddingRequest(
            input: .string("Test embedding"),
            model: "text-embedding-ada-002"
        )

        let response = try await actor.createEmbedding(request)

        #expect(response.data.count > 0)
        #expect(response.data.first?.embedding.count == 1536)
    }

    @Test("Batch create chat completions")
    func testBatchCreateChatCompletions() async throws {
        try requireLiveTests()
        let requests = (1...3).map { i in
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [
                    ChatMessage(role: .user, content: .text("Say only the number \(i)"))
                ],
                temperature: 0.0,
                maxTokens: 10
            )
        }

        let results = try await actor.batchCreateChatCompletions(
            requests,
            maxConcurrency: 2
        )

        #expect(results.count == 3)

        for (index, result) in results.enumerated() {
            switch result {
            case .success(let response):
                #expect(response.choices.count > 0)
                if let choice = response.choices.first,
                    case .text(let content) = choice.message.content
                {
                    #expect(content.contains("\(index + 1)"))
                }
            case .failure(let error):
                Issue.record("Request \(index) failed: \(error)")
            }
        }
    }

    @Test("Rate limiting behavior")
    func testRateLimiting() async throws {
        try requireLiveTests()
        // Create actor with very low rate limit for testing
        let rateLimitedActor = OpenAIActor(
            apiKey: TestConstants.apiKey,
            maxRetries: 1,
            retryDelay: 0.1,
            maxRequestsPerMinute: 2  // Very low for testing
        )

        let startTime = Date()

        // Make 3 quick requests (should trigger rate limiting)
        let requests = (1...3).map { _ in
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [
                    ChatMessage(role: .user, content: .text("Hi"))
                ],
                temperature: 0.0,
                maxTokens: 5
            )
        }

        // Execute requests sequentially to test rate limiting
        for request in requests {
            _ = try? await rateLimitedActor.createChatCompletion(request)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // With rate limit of 2/minute, the 3rd request should wait
        // This is a rough test as exact timing can vary
        #expect(duration > 1.0)  // Should take more than 1 second due to rate limiting
    }

    @Test("Concurrent batch operations")
    func testConcurrentBatchOperations() async throws {
        try requireLiveTests()
        let batchSize = 5
        let maxConcurrency = 3

        let requests = (1...batchSize).map { i in
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [
                    ChatMessage(role: .user, content: .text("Echo: \(i)"))
                ],
                temperature: 0.0,
                maxTokens: 10
            )
        }

        let results = try await actor.batchCreateChatCompletions(
            requests,
            maxConcurrency: maxConcurrency
        )

        #expect(results.count == batchSize)

        let successCount = results.filter { result in
            if case .success = result { return true }
            return false
        }.count

        #expect(successCount == batchSize)
    }

    @Test("Error handling in batch operations")
    func testBatchErrorHandling() async throws {
        try requireLiveTests()
        // Mix valid and invalid requests
        let requests = [
            // Valid request
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [ChatMessage(role: .user, content: .text("Hello"))],
                maxTokens: 10
            ),
            // Invalid request (empty messages)
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [],
                maxTokens: 10
            ),
            // Valid request
            ChatRequest(
                model: TestConstants.Models.chat,
                messages: [ChatMessage(role: .user, content: .text("World"))],
                maxTokens: 10
            ),
        ]

        let results = try await actor.batchCreateChatCompletions(
            requests,
            maxConcurrency: 2
        )

        #expect(results.count == 3)

        // First request should succeed
        if case .failure = results[0] {
            Issue.record("First request should have succeeded")
        }

        // Second request should fail (empty messages)
        if case .success = results[1] {
            Issue.record("Second request should have failed")
        }

        // Third request should succeed
        if case .failure = results[2] {
            Issue.record("Third request should have succeeded")
        }
    }
}
