import Foundation
import Testing

@testable import OpenAISwift

@Suite("Performance Tests")
struct PerformanceTests {
    let api: OpenAI

    init() {
        self.api = OpenAI(apiKey: TestConstants.apiKey)
    }

    @Test(
        "Concurrent API calls performance",
        .enabled(
            if: ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE"] == "1",
            "Enable performance benchmarks with ENABLE_PERFORMANCE=1"
        )
    )
    func testConcurrentPerformance() async throws {
        try requireLiveTests()
        let startTime = Date()
        let concurrentRequests = 10

        await withTaskGroup(of: Result<ChatResponse, Error>.self) { group in
            for i in 1...concurrentRequests {
                group.addTask {
                    do {
                        let request = ChatRequest(
                            model: TestConstants.Models.chat,
                            messages: [
                                ChatMessage(role: .user, content: .text("Say only the number \(i)"))
                            ],
                            temperature: 0.0,
                            maxTokens: 10
                        )
                        let response = try await self.api.createChatCompletion(request)
                        return .success(response)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var successCount = 0
            for await result in group {
                if case .success = result {
                    successCount += 1
                }
            }

            #expect(successCount == concurrentRequests)
        }

        let duration = Date().timeIntervalSince(startTime)
        print("Completed \(concurrentRequests) concurrent requests in \(duration) seconds")

        // Should complete reasonably quickly with concurrent execution
        #expect(duration < 30.0)
    }

    @Test(
        "Large batch embedding performance",
        .enabled(
            if: ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE"] == "1",
            "Enable performance benchmarks with ENABLE_PERFORMANCE=1"
        ))
    func testLargeBatchEmbeddingPerformance() async throws {
        try requireLiveTests()
        // Generate 100 text samples
        let texts = (1...100).map { "This is sample text number \($0) for embedding generation" }

        let startTime = Date()

        // OpenAI has a limit on batch size, so we need to chunk
        let batchSize = 50
        var allEmbeddings: [EmbeddingData] = []

        for i in stride(from: 0, to: texts.count, by: batchSize) {
            let batch = Array(texts[i..<min(i + batchSize, texts.count)])
            let request = EmbeddingRequest(
                input: .array(batch),
                model: TestConstants.Models.embedding
            )

            let response = try await api.createEmbedding(request)
            allEmbeddings.append(contentsOf: response.data)
        }

        let duration = Date().timeIntervalSince(startTime)

        #expect(allEmbeddings.count == texts.count)
        print("Generated \(texts.count) embeddings in \(duration) seconds")

        // Calculate average time per embedding
        let avgTime = duration / Double(texts.count)
        print("Average time per embedding: \(avgTime) seconds")

        #expect(avgTime < 1.0)  // Should be much faster in batches
    }

    @Test(
        "Streaming latency measurement",
        .enabled(
            if: ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE"] == "1",
            "Enable performance benchmarks with ENABLE_PERFORMANCE=1"
        ))
    func testStreamingLatency() async throws {
        try requireLiveTests()
        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [
                ChatMessage(role: .user, content: .text("Count from 1 to 10"))
            ],
            temperature: 0.0,
            stream: true
        )

        let startTime = Date()
        var firstChunkTime: Date?
        var chunkCount = 0

        let stream = try await api.createChatCompletionStream(request)

        for try await _ in stream {
            if firstChunkTime == nil {
                firstChunkTime = Date()
            }
            chunkCount += 1
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        let timeToFirstChunk = firstChunkTime?.timeIntervalSince(startTime) ?? 0

        print("Streaming stats:")
        print("- Time to first chunk: \(timeToFirstChunk) seconds")
        print("- Total duration: \(totalDuration) seconds")
        print("- Number of chunks: \(chunkCount)")
        print(
            "- Average chunk interval: \((totalDuration - timeToFirstChunk) / Double(max(chunkCount - 1, 1))) seconds"
        )

        // First chunk should arrive quickly
        #expect(timeToFirstChunk < 2.0)
        #expect(chunkCount > 5)
    }

    @Test(
        "Memory efficiency with large responses",
        .enabled(
            if: ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE"] == "1",
            "Enable performance benchmarks with ENABLE_PERFORMANCE=1"
        ))
    func testMemoryEfficiency() async throws {
        try requireLiveTests()
        let initialMemory = getMemoryUsage()

        // Request a longer response
        let request = ChatRequest(
            model: TestConstants.Models.chat,
            messages: [
                ChatMessage(
                    role: .user,
                    content: .text(
                        "Generate a detailed 500-word essay about the history of computing")
                )
            ],
            maxTokens: 1000
        )

        let response = try await api.createChatCompletion(request)

        let afterRequestMemory = getMemoryUsage()
        let memoryIncrease = afterRequestMemory - initialMemory

        print("Memory usage increased by \(memoryIncrease / 1024 / 1024) MB")

        #expect(response.choices.count > 0)

        // Memory increase should be reasonable
        #expect(memoryIncrease < 50 * 1024 * 1024)  // Less than 50MB
    }

    @Test(
        "Token usage tracking",
        .enabled(
            if: ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE"] == "1",
            "Enable performance benchmarks with ENABLE_PERFORMANCE=1"
        ))
    func testTokenUsageTracking() async throws {
        try requireLiveTests()
        var totalTokens = 0
        let requests = 5

        for i in 1...requests {
            let request = ChatRequest(
                model: TestConstants.Models.chat,
                messages: [
                    ChatMessage(
                        role: .user,
                        content: .text("Write a \(i * 10)-word story")
                    )
                ],
                maxTokens: i * 50
            )

            let response = try await api.createChatCompletion(request)

            if let usage = response.usage {
                totalTokens += usage.totalTokens ?? 0
                if let tokens = usage.totalTokens {
                    print("Request \(i) used \(tokens) tokens")
                }
            }
        }

        print("Total tokens used: \(totalTokens)")
        #expect(totalTokens > 0)
    }

    // MARK: - Helpers

    // Helper function to get memory usage
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
