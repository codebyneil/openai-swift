import Foundation
import Testing

@testable import OpenAISwift

// MARK: - Chat Completion Fixture

@Suite("Chat Completion Fixture Tests")
struct ChatCompletionFixtureTests {
    @Test("Decode chat completion fixture")
    func testChatCompletionDecoding() throws {
        let data = try FixtureLoader.loadData("chat_completion")
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        #expect(!response.id.isEmpty)
        #expect(response.choices.count > 0)
        #expect(response.object == "chat.completion")
    }
}

// MARK: - Chat Completion with Functions Fixture

@Suite("Chat Completion (Functions) Fixture Tests")
struct ChatCompletionFunctionsFixtureTests {
    @Test("Decode chat completion with functions fixture")
    func testChatCompletionFunctionsDecoding() throws {
        let data = try FixtureLoader.loadData("chat_completion_functions")
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        #expect(response.choices.count > 0)
    }
}

// MARK: - Embedding Fixture

@Suite("Embedding Fixture Tests")
struct EmbeddingFixtureTests {
    @Test("Decode embedding fixture")
    func testEmbeddingDecoding() throws {
        let data = try FixtureLoader.loadData("embedding")
        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

        #expect(response.data.count > 0)
        if let first = response.data.first {
            #expect(first.embedding.count > 0)
        }
    }
}

// MARK: - Image Generation Fixture

@Suite("Image Generation Fixture Tests")
struct ImageGenerationFixtureTests {
    @Test("Decode image generation fixture")
    func testImageGenerationDecoding() throws {
        let data = try FixtureLoader.loadData("image_generation")
        let response = try JSONDecoder().decode(ImageResponse.self, from: data)

        #expect(response.data.count == 1)
        #expect(response.created > 0)
    }
}

// MARK: - Models List Fixture

@Suite("Models List Fixture Tests")
struct ModelsListFixtureTests {
    @Test("Decode models list fixture")
    func testModelsListDecoding() throws {
        let data = try FixtureLoader.loadData("models_list")
        let response = try JSONDecoder().decode(ModelList.self, from: data)

        #expect(response.object == "list")
        #expect(response.data.count > 10)
    }
}
