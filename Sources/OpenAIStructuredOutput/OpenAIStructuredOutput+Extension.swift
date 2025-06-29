import Foundation
import OpenAIChat
import OpenAICore

// MARK: - Convenience Extension for OpenAI

/// Extensions to the OpenAI client for structured output support.
///
/// These extensions provide convenient methods for making chat completion requests
/// with structured output requirements, automatically handling schema generation
/// and response parsing.
extension OpenAI {

    /// Creates a chat completion with structured output for any Decodable type.
    ///
    /// This method automatically generates a JSON Schema for the response type
    /// and configures the API request to return structured data. The response
    /// is automatically decoded into the specified type.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion (e.g., "gpt-4")
    ///   - messages: Array of chat messages for the conversation
    ///   - responseType: The Decodable type to decode the response into
    ///   - temperature: Controls randomness (0-2), lower is more deterministic
    ///   - maxTokens: Maximum tokens to generate
    ///   - strict: Whether to enforce strict schema validation (default: true)
    /// - Returns: The decoded response of type T
    /// - Throws: `OpenAIError` if the request fails or response cannot be decoded
    ///
    /// ## Example
    /// ```swift
    /// struct WeatherInfo: Decodable {
    ///     let temperature: Double
    ///     let condition: String
    /// }
    ///
    /// let weather = try await openAI.createChatCompletion(
    ///     model: "gpt-4",
    ///     messages: [.user("What's the weather?")],
    ///     responseType: WeatherInfo.self
    /// )
    /// ```
    ///
    /// ## Note
    /// This method attempts to create a temporary instance for schema generation,
    /// which may fail for types without a default initializer. Consider using
    /// the StructuredOutputConvertible version for better control.
    public func createChatCompletion<T: Decodable>(
        model: String,
        messages: [ChatMessage],
        responseType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        strict: Bool = true
    ) async throws -> T {
        // Use the new type-based method
        return try await createChatCompletionTyped(
            model: model,
            messages: messages,
            responseType: responseType,
            temperature: temperature,
            maxTokens: maxTokens,
            strict: strict
        )
    }

    /// Creates a chat completion with structured output for StructuredOutputConvertible types.
    ///
    /// This method uses the type's own schema generation logic for better control
    /// over the structured output format. Types conforming to StructuredOutputConvertible
    /// can define custom schemas with specific constraints.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion (e.g., "gpt-4")
    ///   - messages: Array of chat messages for the conversation
    ///   - responseType: The type conforming to both StructuredOutputConvertible and Decodable
    ///   - temperature: Controls randomness (0-2), lower is more deterministic
    ///   - maxTokens: Maximum tokens to generate
    ///   - strict: Whether to enforce strict schema validation (default: true)
    /// - Returns: The decoded response of type T
    /// - Throws: `OpenAIError` if the request fails or response cannot be decoded
    ///
    /// ## Example
    /// ```swift
    /// struct CustomResponse: StructuredOutputConvertible, Decodable {
    ///     let result: String
    ///     let confidence: Double
    ///
    ///     static func generateStructuredOutput() -> [String: Any] {
    ///         return [
    ///             "type": "object",
    ///             "properties": [
    ///                 "result": ["type": "string"],
    ///                 "confidence": ["type": "number", "minimum": 0, "maximum": 1]
    ///             ],
    ///             "required": ["result", "confidence"]
    ///         ]
    ///     }
    /// }
    ///
    /// let response = try await openAI.createChatCompletion(
    ///     model: "gpt-4",
    ///     messages: messages,
    ///     responseType: CustomResponse.self
    /// )
    /// ```
    public func createChatCompletion<T: StructuredOutputConvertible & Decodable>(
        model: String,
        messages: [ChatMessage],
        responseType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        strict: Bool = true
    ) async throws -> T {
        // Use the StructuredOutputConvertible protocol for better schema generation
        let responseFormat = ResponseFormatBuilder.buildResponseFormat(
            for: responseType,
            strict: strict
        )

        // Create the request with response format
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat
        )

        // Make the API call
        let response = try await createChatCompletion(request)

        // Extract and decode the JSON response
        guard let message = response.choices.first?.message,
            case .text(let jsonString) = message.content,
            let jsonData = jsonString.data(using: String.Encoding.utf8)
        else {
            throw OpenAIError.missingData
        }

        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            throw OpenAIError.decodingError(error)
        }
    }
}

// MARK: - Structured Output Request Builder

/// A builder for creating structured chat completion requests.
///
/// `StructuredChatRequest` encapsulates all parameters needed for a structured
/// output chat completion, providing a cleaner API for complex requests.
///
/// ## Example
/// ```swift
/// let request = StructuredChatRequest(
///     model: "gpt-4",
///     messages: conversation,
///     responseType: Analysis.self,
///     temperature: 0.7
/// )
///
/// let result = try await request.execute(with: openAI)
/// ```
public struct StructuredChatRequest<T: Decodable> {
    public let model: String
    public let messages: [ChatMessage]
    public let responseType: T.Type
    public let temperature: Double?
    public let maxTokens: Int?
    public let strict: Bool

    /// Creates a structured chat request configuration.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion
    ///   - messages: Array of chat messages for the conversation
    ///   - responseType: The Decodable type for the response
    ///   - temperature: Controls randomness (0-2)
    ///   - maxTokens: Maximum tokens to generate
    ///   - strict: Whether to enforce strict schema validation
    public init(
        model: String,
        messages: [ChatMessage],
        responseType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        strict: Bool = true
    ) {
        self.model = model
        self.messages = messages
        self.responseType = responseType
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.strict = strict
    }

    /// Executes the structured chat request using the provided OpenAI client.
    ///
    /// - Parameter api: The OpenAI client instance to use
    /// - Returns: The decoded response of type T
    /// - Throws: `OpenAIError` if the request fails or response cannot be decoded
    ///
    /// ## Example
    /// ```swift
    /// let request = StructuredChatRequest(
    ///     model: "gpt-4",
    ///     messages: messages,
    ///     responseType: Summary.self
    /// )
    ///
    /// let summary = try await request.execute(with: openAIClient)
    /// ```
    public func execute(with api: OpenAI) async throws -> T {
        return try await api.createChatCompletion(
            model: model,
            messages: messages,
            responseType: responseType,
            temperature: temperature,
            maxTokens: maxTokens,
            strict: strict
        )
    }
}
