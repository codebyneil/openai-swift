import Foundation
import Testing

@testable import OpenAISwift

@Suite("Concurrent Operations Tests")
struct ConcurrentOperationsTests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey)
    }

    @Test("Concurrent different operation types")
    func testMixedConcurrentOperations() async throws {
        try requireLiveTests()
        async let chatTask = performChatCompletion()
        async let embeddingTask = performEmbedding()
        async let modelsTask = performModelsList()

        let (chatResult, embeddingResult, modelsResult) = try await (
            chatTask, embeddingTask, modelsTask
        )

        #expect(chatResult)
        #expect(embeddingResult)
        #expect(modelsResult)
    }

    @Test("Concurrent streaming operations")
    func testConcurrentStreaming() async throws {
        try requireLiveTests()
        let prompts = [
            "Count from 1 to 3",
            "List three colors",
            "Name three animals",
        ]

        await withTaskGroup(of: (Int, String).self) { group in
            for (index, prompt) in prompts.enumerated() {
                group.addTask {
                    let request = ChatRequest(
                        model: "gpt-3.5-turbo",
                        messages: [ChatMessage(role: .user, content: .text(prompt))],
                        temperature: 0.0,
                        stream: true
                    )

                    var fullContent = ""
                    do {
                        let stream = try await self.api.createChatCompletionStream(request)
                        for try await chunk in stream {
                            if let delta = chunk.choices.first?.delta,
                                let text = delta.content
                            {
                                fullContent += text
                            }
                        }
                    } catch {
                        print("Stream \(index) failed: \(error)")
                    }

                    return (index, fullContent)
                }
            }

            var results = Array(repeating: "", count: prompts.count)
            for await (index, content) in group {
                results[index] = content
            }

            // Verify all streams completed
            for (index, content) in results.enumerated() {
                #expect(content.count > 0, "Stream \(index) should have content")
            }
        }
    }

    @Test("Race condition testing")
    func testRaceConditions() async throws {
        try requireLiveTests()
        let sharedMessages = ChatMessage(role: .user, content: .text("Hello"))
        let iterations = 20

        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let request = ChatRequest(
                        model: "gpt-3.5-turbo",
                        messages: [sharedMessages],
                        temperature: 0.0,
                        maxTokens: 10,
                        user: "user-\(i)"
                    )

                    do {
                        let response = try await self.api.createChatCompletion(request)
                        return response.choices.count > 0
                    } catch {
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }

            #expect(successCount == iterations)
        }
    }

    @Test("Cancellation handling")
    func testCancellationHandling() async throws {
        try requireLiveTests()
        let task = Task {
            let request = ChatRequest(
                model: "gpt-3.5-turbo",
                messages: [
                    ChatMessage(
                        role: .user,
                        content: .text("Write a very long story with 1000 words")
                    )
                ],
                stream: true
            )

            let stream = try await api.createChatCompletionStream(request)
            var chunks = 0

            for try await _ in stream {
                chunks += 1
                try Task.checkCancellation()
            }

            return chunks
        }

        // Let it start
        try await Task.sleep(for: .milliseconds(500))

        // Cancel it
        task.cancel()

        do {
            let chunks = try await task.value
            print("Received \(chunks) chunks before cancellation")
        } catch {
            // Expected cancellation error
            #expect(error is CancellationError)
        }
    }

    // Helper methods
    private func performChatCompletion() async throws -> Bool {
        let request = ChatRequest(
            model: "gpt-3.5-turbo",
            messages: [ChatMessage(role: .user, content: .text("Hi"))],
            maxTokens: 10
        )

        let response = try await api.createChatCompletion(request)
        return response.choices.count > 0
    }

    private func performEmbedding() async throws -> Bool {
        let request = EmbeddingRequest(
            input: .string("Test"),
            model: "text-embedding-ada-002"
        )

        let response = try await api.createEmbedding(request)
        return response.data.count > 0
    }

    private func performModelsList() async throws -> Bool {
        let models = try await api.listModels()
        return models.data.count > 0
    }
}
