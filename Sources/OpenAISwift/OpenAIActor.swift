import Foundation
import OSLog
import OpenAIAudio
import OpenAIChat
import OpenAICore
import OpenAIEmbeddings
import OpenAIImages

/// A thread-safe, actor-based OpenAI API client with built-in rate limiting.
///
/// `OpenAIActor` provides all the functionality of ``OpenAI`` but with additional
/// thread-safety guarantees and automatic rate limiting. It's ideal for applications
/// that need to make concurrent API calls or want to avoid rate limit errors.
///
/// ## Overview
///
/// The actor automatically manages:
/// - Thread-safe access to the API
/// - Rate limiting (configurable requests per minute)
/// - Retry logic with exponential backoff
/// - Batch operations with concurrency control
///
/// ## Example
///
/// ```swift
/// let openAI = OpenAIActor(
///     apiKey: "your-api-key",
///     maxRequestsPerMinute: 60
/// )
///
/// // Single request
/// let response = try await openAI.createChatCompletion(request)
///
/// // Batch requests with automatic rate limiting
/// let results = try await openAI.batchCreateChatCompletions(
///     requests,
///     maxConcurrency: 3
/// )
/// ```
///
/// ## Topics
///
/// ### Creating an Actor
/// - ``init(apiKey:organization:maxRetries:retryDelay:maxRequestsPerMinute:)``
///
/// ### Chat Operations
/// - ``createChatCompletion(_:)``
/// - ``createChatCompletionStream(_:)``
/// - ``batchCreateChatCompletions(_:maxConcurrency:)``
///
/// ### Embeddings
/// - ``createEmbedding(_:)``
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public actor OpenAIActor {
    private let apiKey: String
    private let organization: String?
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    private let session: URLSession
    let maxRetries: Int
    private let retryDelay: TimeInterval
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "com.openai.swift", category: "API")

    // Rate limiting
    private var requestCount = 0
    private var requestWindowStart = Date()
    private let maxRequestsPerMinute: Int

    /// Creates a new thread-safe OpenAI API client with rate limiting.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - organization: Optional organization ID for requests.
    ///   - maxRetries: Maximum number of retry attempts for failed requests. Defaults to 3.
    ///   - retryDelay: Base delay in seconds between retry attempts. Defaults to 1.0.
    ///   - maxRequestsPerMinute: Maximum API requests allowed per minute. Defaults to 60.
    ///
    /// - Note: The actor automatically configures a URLSession optimized for API calls
    ///   with multipath networking support on supported platforms.
    public init(
        apiKey: String,
        organization: String? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        maxRequestsPerMinute: Int = 60
    ) {
        self.apiKey = apiKey
        self.organization = organization
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.maxRequestsPerMinute = maxRequestsPerMinute

        // Configure URLSession with modern networking features
        let configuration = URLSessionConfiguration.default
        #if !os(macOS)
            configuration.multipathServiceType = .handover
        #endif
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300

        self.session = URLSession(configuration: configuration)

        // Configure JSON decoder
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Configure JSON encoder
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Rate Limiting

    private func checkRateLimit() async throws {
        let now = Date()
        let windowDuration: TimeInterval = 60  // 1 minute

        if now.timeIntervalSince(requestWindowStart) > windowDuration {
            // Reset window
            requestCount = 0
            requestWindowStart = now
        }

        if requestCount >= maxRequestsPerMinute {
            let waitTime = windowDuration - now.timeIntervalSince(requestWindowStart)
            logger.warning("Rate limit reached, waiting \(waitTime, privacy: .public) seconds")
            try await Task.sleep(for: .seconds(waitTime))
            requestCount = 0
            requestWindowStart = Date()
        }

        requestCount += 1
    }

    // MARK: - API Methods

    /// Creates a chat completion with automatic rate limiting.
    ///
    /// - Parameter request: The chat completion request.
    /// - Returns: The chat completion response.
    /// - Throws: ``OpenAIError`` for API errors or rate limit violations.
    public func createChatCompletion(_ request: ChatRequest) async throws -> ChatResponse {
        try await checkRateLimit()

        logger.info("Creating chat completion with model: \(request.model, privacy: .public)")

        let api = OpenAI(apiKey: apiKey, organization: organization, session: session)
        return try await api.createChatCompletion(request)
    }

    /// Creates a streaming chat completion with automatic rate limiting.
    ///
    /// - Parameter request: The chat completion request with `stream: true`.
    /// - Returns: An async stream that yields response chunks as they arrive.
    /// - Throws: ``OpenAIError`` for API errors or rate limit violations.
    public func createChatCompletionStream(_ request: ChatRequest) async throws
        -> AsyncThrowingStream<ChatCompletionStreamResponse, Error>
    {
        try await checkRateLimit()

        logger.info(
            "Creating streaming chat completion with model: \(request.model, privacy: .public)")

        let api = OpenAI(apiKey: apiKey, organization: organization, session: session)
        return try await api.createChatCompletionStream(request)
    }

    /// Creates embeddings for the provided input with automatic rate limiting.
    ///
    /// - Parameter request: The embedding request.
    /// - Returns: The embedding response containing vector representations.
    /// - Throws: ``OpenAIError`` for API errors or rate limit violations.
    public func createEmbedding(_ request: EmbeddingRequest) async throws -> EmbeddingResponse {
        try await checkRateLimit()

        logger.info("Creating embedding with model: \(request.model, privacy: .public)")

        let api = OpenAI(apiKey: apiKey, organization: organization, session: session)
        return try await api.createEmbedding(request)
    }

    // MARK: - Batch Operations

    /// Processes multiple chat completion requests concurrently with rate limiting.
    ///
    /// This method efficiently handles batch operations by:
    /// - Running requests concurrently up to the specified limit
    /// - Automatically managing rate limits across all requests
    /// - Returning results in the same order as input requests
    ///
    /// - Parameters:
    ///   - requests: Array of chat completion requests to process.
    ///   - maxConcurrency: Maximum number of concurrent requests. Defaults to 5.
    ///
    /// - Returns: Array of results matching the order of input requests.
    ///   Each result is either `.success(ChatResponse)` or `.failure(Error)`.
    ///
    /// - Note: Failed requests don't stop the batch; each failure is captured
    ///   in the corresponding result.
    public func batchCreateChatCompletions(
        _ requests: [ChatRequest],
        maxConcurrency: Int = 5
    ) async throws -> [Result<ChatResponse, Error>] {
        logger.info("Processing batch of \(requests.count) chat completions")

        return await withTaskGroup(of: (Int, Result<ChatResponse, Error>).self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrency)

            for (index, request) in requests.enumerated() {
                group.addTask {
                    await semaphore.wait()

                    do {
                        try await self.checkRateLimit()
                        let response = try await self.createChatCompletion(request)
                        await semaphore.signal()
                        return (index, .success(response))
                    } catch {
                        self.logger.error(
                            "Batch request \(index) failed: \(error, privacy: .public)")
                        await semaphore.signal()
                        return (index, .failure(error))
                    }
                }
            }

            var results = [Result<ChatResponse, Error>?](repeating: nil, count: requests.count)
            for await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }
}

// MARK: - Async Semaphore

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - Usage Example
/*
let openAI = OpenAIActor(apiKey: "your-key")

// Single request
let response = try await openAI.createChatCompletion(request)

// Batch requests with automatic rate limiting
let results = try await openAI.batchCreateChatCompletions(requests, maxConcurrency: 3)
*/
