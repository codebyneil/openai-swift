import Foundation
import OpenAICore

extension OpenAI {
    /// Creates a chat completion for the provided messages.
    ///
    /// Sends a chat completion request to the OpenAI API and returns the generated response.
    ///
    /// - Parameter request: The chat completion request containing model, messages, and other parameters.
    /// - Returns: A `ChatResponse` containing the generated message and metadata.
    /// - Throws: An error if the request fails or the response cannot be decoded.
    ///
    /// ## Example
    /// ```swift
    /// let response = try await openAI.createChatCompletion(ChatRequest(
    ///     model: "gpt-3.5-turbo",
    ///     messages: [
    ///         ChatMessage(role: .user, content: .text("Hello!"))
    ///     ]
    /// ))
    /// print(response.choices.first?.message.content)
    /// ```
    public func createChatCompletion(_ request: ChatRequest) async throws -> ChatResponse {
        let (data, response) = try await makeRequest(endpoint: "chat/completions", body: request)
        return try decodeResponse(ChatResponse.self, from: data, response: response)
    }

    /// Creates a streaming chat completion for the provided messages.
    ///
    /// Returns an async stream that yields chat completion chunks as they are generated.
    /// This allows for real-time streaming of the model's response.
    ///
    /// - Parameter request: The chat completion request. The `stream` parameter will be set to `true`.
    /// - Returns: An `AsyncThrowingStream` that yields `ChatCompletionStreamResponse` chunks.
    /// - Throws: An error if the stream setup fails.
    ///
    /// ## Example
    /// ```swift
    /// let stream = try await openAI.createChatCompletionStream(ChatRequest(
    ///     model: "gpt-3.5-turbo",
    ///     messages: [ChatMessage(role: .user, content: .text("Tell me a story"))]
    /// ))
    ///
    /// for try await chunk in stream {
    ///     if let content = chunk.choices.first?.delta.content {
    ///         print(content, terminator: "")
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The original request's `stream` parameter is automatically overridden to `true`.
    public func createChatCompletionStream(_ request: ChatRequest) async throws
        -> AsyncThrowingStream<ChatCompletionStreamResponse, Error>
    {
        var streamRequest = request
        streamRequest = ChatRequest(
            model: request.model,
            messages: request.messages,
            temperature: request.temperature,
            topP: request.topP,
            n: request.n,
            stream: true,
            stop: request.stop,
            maxTokens: request.maxTokens,
            presencePenalty: request.presencePenalty,
            frequencyPenalty: request.frequencyPenalty,
            logitBias: request.logitBias,
            user: request.user,
            responseFormat: request.responseFormat,
            seed: request.seed,
            tools: request.tools,
            toolChoice: request.toolChoice,
            parallelToolCalls: request.parallelToolCalls
        )

        return try await makeStreamingRequest(
            endpoint: "chat/completions",
            body: streamRequest,
            responseType: ChatCompletionStreamResponse.self
        )
    }
}
