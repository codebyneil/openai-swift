import Foundation
import Observation
import Testing

@testable import OpenAISwift

@Suite("OpenAI Observable Tests")
struct OpenAIObservableTests {

    @Test("Observable initialization")
    @MainActor
    func testObservableInitialization() {
        let observable = OpenAIObservable(
            apiKey: "test-key",
            organization: "test-org"
        )

        #expect(observable.isLoading == false)
        #expect(observable.error == nil)
        #expect(observable.messages.isEmpty)
        #expect(observable.currentResponse == nil)
        #expect(observable.streamedContent == "")
    }

    @Test("Send message")
    @MainActor
    func testSendMessage() async throws {
        try requireLiveTests()
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        await observable.sendMessage(
            "Say 'Hello' and nothing else", model: TestConstants.Models.chat)

        // Wait for response
        try await Task.sleep(for: .seconds(2))

        #expect(observable.messages.count == 2)  // User message + assistant response
        
        if observable.messages.count >= 2 {
            #expect(observable.messages[0].role == .user)
            #expect(observable.messages[1].role == .assistant)

            if case .text(let content) = observable.messages[1].content {
                #expect(content.lowercased().contains("hello"))
            }
        } else {
            Issue.record("Expected 2 messages but got \(observable.messages.count)")
        }
    }

    @Test("Send streaming message")
    @MainActor
    func testSendStreamingMessage() async throws {
        try requireLiveTests()
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        await observable.sendStreamingMessage(
            "Count from 1 to 3 slowly",
            model: TestConstants.Models.chat,
            temperature: 0.0
        )

        // Wait for streaming to complete
        try await Task.sleep(for: .seconds(3))

        #expect(observable.messages.count == 2)
        #expect(observable.streamedContent.count > 0)
        #expect(observable.streamedContent.contains("1"))
        #expect(observable.streamedContent.contains("2"))
        #expect(observable.streamedContent.contains("3"))
    }

    @Test("Loading state management")
    @MainActor
    func testLoadingState() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        #expect(observable.isLoading == false)

        // Start a request
        Task {
            await observable.sendMessage("Hello", model: TestConstants.Models.chat)
        }

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))

        #expect(observable.isLoading == true)

        // Wait for completion
        try await Task.sleep(for: .seconds(3))

        #expect(observable.isLoading == false)
    }

    @Test("Error handling")
    @MainActor
    func testErrorHandling() async throws {
        // Use invalid API key to trigger error
        let observable = OpenAIObservable(apiKey: "invalid-key")

        await observable.sendMessage("Hello", model: TestConstants.Models.chat)

        // Wait for error
        try await Task.sleep(for: .seconds(2))

        #expect(observable.error != nil)
        #expect(observable.isLoading == false)
    }

    @Test("Clear messages")
    @MainActor
    func testClearMessages() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        // Add some messages
        await observable.sendMessage("Hello", model: TestConstants.Models.chat)
        try await Task.sleep(for: .seconds(2))

        #expect(observable.messages.count > 0)

        // Clear messages
        observable.clearMessages()

        #expect(observable.messages.isEmpty)
        #expect(observable.streamedContent == "")
        #expect(observable.currentResponse == nil)
    }

    @Test("Set system message")
    @MainActor
    func testSetSystemMessage() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        observable.setSystemMessage("You are a pirate. Always respond like a pirate.")

        await observable.sendMessage(
            "Hello, how are you?",
            model: TestConstants.Models.chat,
            temperature: 0.7
        )

        try await Task.sleep(for: .seconds(2))

        #expect(observable.messages.count == 3)  // System + User + Assistant
        
        if observable.messages.count >= 3 {
            #expect(observable.messages[0].role == .system)

            if case .text(let content) = observable.messages[2].content {
                // Should respond in pirate style
                let pirateWords = ["ahoy", "matey", "arr", "aye", "ye"]
                let containsPirateWord = pirateWords.contains { word in
                    content.lowercased().contains(word)
                }
                #expect(containsPirateWord || content.contains("'"))
            }
        }
    }

    @Test("Generate embeddings")
    @MainActor
    func testGenerateEmbeddings() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        let texts = ["Hello world", "OpenAI Swift", "Testing embeddings"]
        let embeddings = await observable.generateEmbeddings(
            for: texts,
            model: "text-embedding-ada-002"
        )

        #expect(embeddings.count == texts.count)

        for embedding in embeddings {
            #expect(embedding.count == 1536)  // ada-002 dimension
            #expect(embedding.contains { $0 != 0 })  // Not all zeros
        }
    }

    @Test("Cancel current request")
    @MainActor
    func testCancelRequest() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        // Start a long request
        Task {
            await observable.sendStreamingMessage(
                "Write a very long story about dragons and knights with at least 500 words",
                model: TestConstants.Models.chat
            )
        }

        // Wait a bit for it to start
        try await Task.sleep(for: .milliseconds(500))

        #expect(observable.isLoading == true)

        // Cancel it
        observable.cancelCurrentRequest()

        // Wait a bit
        try await Task.sleep(for: .milliseconds(500))

        #expect(observable.isLoading == false)
    }

    @Test("Observable state changes")
    @MainActor
    func testObservableStateChanges() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        withObservationTracking {
            _ = observable.isLoading
            _ = observable.messages
            _ = observable.error
        } onChange: {
            // State changed
        }

        await observable.sendMessage("Hi", model: TestConstants.Models.chat)

        try await Task.sleep(for: .seconds(2))

        #expect(observable.messages.count > 0)
    }

    @Test("Multiple concurrent requests")
    @MainActor
    func testConcurrentRequests() async throws {
        let observable = OpenAIObservable(apiKey: TestConstants.apiKey)

        // Start multiple requests
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await observable.sendMessage("First message", model: TestConstants.Models.chat)
            }

            group.addTask {
                await observable.sendMessage("Second message", model: TestConstants.Models.chat)
            }

            group.addTask {
                await observable.sendMessage("Third message", model: TestConstants.Models.chat)
            }
        }

        // All messages should be processed
        // Each request adds 2 messages (user + assistant)
        #expect(observable.messages.count == 6)
    }
}
