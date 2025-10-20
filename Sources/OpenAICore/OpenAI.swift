import Foundation

/// The main client for interacting with the OpenAI API.
///
/// `OpenAI` provides a type-safe, Swift-native interface to all OpenAI API endpoints.
/// It handles authentication, request formatting, and response parsing automatically.
///
/// ## Topics
/// ### Creating a Client
/// - ``init(apiKey:organization:baseURL:session:maxRetries:retryDelay:)``
///
/// ### Making Requests
/// - ``makeRequest(endpoint:method:body:queryItems:)``
/// - ``makeStreamingRequest(endpoint:body:responseType:)``
/// - ``decodeResponse(_:from:response:)``
///
/// ### Configuration
/// - ``apiKey``
/// - ``organization``
/// - ``baseURL``
/// - ``session``
/// - ``decoder``
/// - ``encoder``
public final class OpenAI: Sendable {
    /// The API key used for authenticating requests to the OpenAI API.
    public let apiKey: String

    /// The optional organization ID to use for requests.
    public let organization: String?

    /// The base URL for the OpenAI API.
    public let baseURL: URL

    /// The URLSession used for making network requests.
    public let session: URLSession

    /// Maximum number of retry attempts for failed requests.
    private let maxRetries: Int

    /// Base delay between retry attempts (uses exponential backoff).
    private let retryDelay: TimeInterval

    /// JSON decoder configured for OpenAI API responses.
    public let decoder: JSONDecoder

    /// JSON encoder configured for OpenAI API requests.
    public let encoder: JSONEncoder

    /// Creates a new OpenAI API client.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - organization: Optional organization ID for requests.
    ///   - baseURL: The base URL for the OpenAI API. Defaults to `https://api.openai.com/v1`.
    ///   - session: URLSession to use for requests. Defaults to `.shared`.
    ///   - maxRetries: Maximum number of retry attempts for failed requests. Defaults to 3.
    ///   - retryDelay: Base delay in seconds between retry attempts. Defaults to 1.0.
    ///
    /// - Note: The client automatically configures JSON encoding/decoding with snake_case conversion
    ///   and ISO8601 date formatting.
    public init(
        apiKey: String, organization: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        session: URLSession = .shared, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0
    ) {
        self.apiKey = apiKey
        self.organization = organization
        self.baseURL = baseURL
        self.session = session
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay

        // Configure JSON decoder with improved date handling
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Configure JSON encoder
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    /// Makes an authenticated request to the OpenAI API.
    ///
    /// This method handles authentication headers, request encoding, and automatic retry logic
    /// for transient failures.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "chat/completions").
    ///   - method: HTTP method to use. Defaults to "POST".
    ///   - body: Optional request body to encode as JSON.
    ///   - queryItems: Optional query parameters to append to the URL.
    ///
    /// - Returns: A tuple containing the response data and URLResponse.
    ///
    /// - Throws: ``OpenAIError`` for API errors or network failures.
    public func makeRequest<T: Encodable>(
        endpoint: String,
        method: String = "POST",
        body: T? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> (Data, URLResponse) {
        var url = baseURL.appendingPathComponent(endpoint)

        if let queryItems = queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            url = components.url!
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        return try await performRequestWithRetry(request)
    }

    public func makeRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) async throws -> (Data, URLResponse) {
        var url = baseURL.appendingPathComponent(endpoint)

        if let queryItems = queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            url = components.url!
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        return try await performRequestWithRetry(request)
    }

    /// Makes a streaming request to the OpenAI API.
    ///
    /// Use this method for endpoints that support Server-Sent Events (SSE) streaming,
    /// such as chat completions with `stream: true`.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - body: The request body to encode as JSON.
    ///   - responseType: The expected response type for each streamed chunk.
    ///
    /// - Returns: An async stream that yields response chunks as they arrive.
    ///
    /// - Throws: ``OpenAIError`` for API errors or network failures.
    ///
    /// ## Example
    /// ```swift
    /// let stream = try await openAI.makeStreamingRequest(
    ///     endpoint: "chat/completions",
    ///     body: request,
    ///     responseType: ChatCompletionStreamResponse.self
    /// )
    ///
    /// for try await chunk in stream {
    ///     print(chunk.choices.first?.delta.content ?? "")
    /// }
    /// ```
    public func makeStreamingRequest<T: Encodable, Response: Decodable & Sendable>(
        endpoint: String,
        body: T,
        responseType: Response.Type
    ) async throws -> AsyncThrowingStream<Response, Error> {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        request.httpBody = try encoder.encode(body)

        let requestCopy = request
        let sessionCopy = session
        let decoderCopy = decoder

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await sessionCopy.bytes(for: requestCopy)

                    guard let httpResponse = response as? HTTPURLResponse,
                        200...299 ~= httpResponse.statusCode
                    else {
                        throw OpenAIError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8),
                                let streamResponse = try? decoderCopy.decode(
                                    Response.self, from: data)
                            {
                                continuation.yield(streamResponse)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Decodes a response from the OpenAI API.
    ///
    /// This method validates the HTTP response and decodes the JSON data into the specified type.
    /// It automatically handles error responses from the API.
    ///
    /// - Parameters:
    ///   - type: The expected response type.
    ///   - data: The response data to decode.
    ///   - response: The URLResponse to validate.
    ///
    /// - Returns: The decoded response object.
    ///
    /// - Throws:
    ///   - ``OpenAIError/invalidResponse`` if the response is not an HTTP response.
    ///   - ``OpenAIError/apiError(_:)`` if the API returned an error.
    ///   - ``OpenAIError/httpError(statusCode:)`` for non-200 HTTP status codes.
    ///   - ``OpenAIError/decodingError(_:)`` if decoding fails.
    public func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse)
        throws -> T
    {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse)
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            var debugInfo: DecodingDebugInfo?
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let ctx):
                    debugInfo = DecodingDebugInfo(
                        reason: .dataCorrupted,
                        codingPath: ctx.codingPath.map { $0.stringValue },
                        debugDescription: ctx.debugDescription,
                        key: nil)
                case .keyNotFound(let key, let ctx):
                    debugInfo = DecodingDebugInfo(
                        reason: .keyNotFound,
                        codingPath: ctx.codingPath.map { $0.stringValue },
                        debugDescription: ctx.debugDescription,
                        key: key.stringValue)
                case .typeMismatch(let type, let ctx):
                    debugInfo = DecodingDebugInfo(
                        reason: .typeMismatch,
                        codingPath: ctx.codingPath.map { $0.stringValue },
                        debugDescription: ctx.debugDescription,
                        key: nil)
                case .valueNotFound(let value, let ctx):
                    debugInfo = DecodingDebugInfo(
                        reason: .valueNotFound,
                        codingPath: ctx.codingPath.map { $0.stringValue },
                        debugDescription: ctx.debugDescription,
                        key: nil)
                @unknown default:
                    debugInfo = DecodingDebugInfo(
                        reason: .other,
                        codingPath: [],
                        debugDescription: "Unknown decoding error",
                        key: nil)
                }
            } else {
                debugInfo = DecodingDebugInfo(
                    reason: .other,
                    codingPath: [],
                    debugDescription: error.localizedDescription,
                    key: nil)
            }

            throw OpenAIError.decodingError(error, info: debugInfo)
        }
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse)
    {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            // Check for task cancellation
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 429, 500, 502, 503, 504:
                        if attempt < maxRetries - 1 {
                            let delay = retryDelay * pow(2.0, Double(attempt))
                            try await Task.sleep(for: .seconds(delay))
                            continue
                        }
                    default:
                        break
                    }
                }

                return (data, response)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 && !Task.isCancelled {
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? OpenAIError.invalidResponse
    }
}
