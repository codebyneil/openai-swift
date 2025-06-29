import Foundation
import Observation
import OpenAIChat
import OpenAICore
import OpenAIEmbeddings

/// An observable wrapper for OpenAI that integrates seamlessly with SwiftUI.
///
/// `OpenAIObservable` provides a reactive interface to the OpenAI API, automatically
/// updating SwiftUI views when state changes. It manages conversation history,
/// loading states, and error handling in a SwiftUI-friendly way.
///
/// ## Overview
///
/// This class is designed to be used as a `@StateObject` or `@ObservedObject` in
/// SwiftUI views. It automatically triggers view updates when:
/// - Messages are sent or received
/// - Loading state changes
/// - Errors occur
/// - Streaming content arrives
///
/// ## Example
///
/// ```swift
/// struct ChatView: View {
///     @StateObject private var openAI = OpenAIObservable(apiKey: "your-key")
///     @State private var message = ""
///
///     var body: some View {
///         VStack {
///             ScrollView {
///                 ForEach(openAI.messages) { message in
///                     MessageBubble(message: message)
///                 }
///             }
///
///             if openAI.isLoading {
///                 ProgressView()
///             }
///
///             HStack {
///                 TextField("Message", text: $message)
///                 Button("Send") {
///                     Task {
///                         await openAI.sendMessage(message)
///                         message = ""
///                     }
///                 }
///                 .disabled(openAI.isLoading)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating an Observable
/// - ``init(apiKey:organization:)``
/// - ``init(api:)``
///
/// ### Observable State
/// - ``isLoading``
/// - ``error``
/// - ``messages``
/// - ``currentResponse``
/// - ``streamedContent``
///
/// ### Sending Messages
/// - ``sendMessage(_:model:temperature:)``
/// - ``sendStreamingMessage(_:model:temperature:)``
///
/// ### Managing Conversations
/// - ``clearMessages()``
/// - ``setSystemMessage(_:)``
///
/// ### Other Operations
/// - ``generateEmbeddings(for:model:)``
/// - ``cancelCurrentRequest()``
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
@Observable
@MainActor
public class OpenAIObservable {
    /// Indicates whether an API request is currently in progress.
    public private(set) var isLoading = false

    /// The most recent error that occurred, if any.
    public private(set) var error: Error?

    /// The conversation history including all messages.
    public private(set) var messages: [ChatMessage] = []

    /// The most recent complete response from the API.
    public private(set) var currentResponse: ChatResponse?

    /// Accumulated content from the current streaming response.
    public private(set) var streamedContent = ""

    private let api: OpenAI
    private var currentTask: Task<Void, Error>?

    /// Creates a new observable OpenAI client.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - organization: Optional organization ID for requests.
    public init(apiKey: String, organization: String? = nil) {
        self.api = OpenAI(apiKey: apiKey, organization: organization)
    }

    /// Creates a new observable wrapper around an existing OpenAI client.
    ///
    /// - Parameter api: An existing ``OpenAI`` instance to wrap.
    public init(api: OpenAI) {
        self.api = api
    }

    /// Sends a message and waits for a complete response.
    ///
    /// This method:
    /// 1. Adds the user message to the conversation history
    /// 2. Sends the entire conversation to the API
    /// 3. Adds the assistant's response to the history
    /// 4. Updates all observable properties
    ///
    /// - Parameters:
    ///   - message: The user's message text.
    ///   - model: The model to use. Defaults to "gpt-3.5-turbo".
    ///   - temperature: Controls randomness (0-2). Higher values make output more random.
    ///
    /// - Note: The method automatically sets `isLoading` to true while processing
    ///   and updates `error` if something goes wrong.
    public func sendMessage(
        _ message: String, model: String = "gpt-3.5-turbo", temperature: Double? = nil
    ) async {
        isLoading = true
        error = nil

        // Add user message
        let userMessage = ChatMessage(role: .user, content: .text(message))
        messages.append(userMessage)

        do {
            let response = try await Task.detached {
                try await self.api.createChatCompletion(
                    ChatRequest(
                        model: model,
                        messages: self.messages,
                        temperature: temperature
                    )
                )
            }.value

            currentResponse = response

            if let choice = response.choices.first {
                messages.append(choice.message)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Sends a message and streams the response as it's generated.
    ///
    /// This method provides a real-time streaming experience by:
    /// 1. Adding the user message to the conversation
    /// 2. Streaming the response token by token
    /// 3. Updating `streamedContent` as tokens arrive
    /// 4. Adding the complete response to the conversation when done
    ///
    /// - Parameters:
    ///   - message: The user's message text.
    ///   - model: The model to use. Defaults to "gpt-3.5-turbo".
    ///   - temperature: Controls randomness (0-2). Higher values make output more random.
    ///
    /// - Note: Watch the `streamedContent` property to display partial responses
    ///   as they arrive.
    public func sendStreamingMessage(
        _ message: String, model: String = "gpt-3.5-turbo", temperature: Double? = nil
    ) async {
        isLoading = true
        error = nil
        streamedContent = ""

        // Add user message
        let userMessage = ChatMessage(role: .user, content: .text(message))
        messages.append(userMessage)

        do {
            let messagesForAPI = self.messages
            let stream = try await Task.detached {
                try await self.api.createChatCompletionStream(
                    ChatRequest(
                        model: model,
                        messages: messagesForAPI,
                        temperature: temperature,
                        stream: true
                    )
                )
            }.value

            var fullContent = ""
            for try await chunk in stream {
                if let delta = chunk.choices.first?.delta,
                    let text = delta.content
                {
                    fullContent += text
                    streamedContent += text
                }
            }

            // Add assistant message with complete response
            let assistantMessage = ChatMessage(role: .assistant, content: .text(fullContent))
            messages.append(assistantMessage)

        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Clears all conversation history and resets the state.
    ///
    /// This method removes all messages, clears any streaming content,
    /// and resets error states. Use this to start a new conversation.
    public func clearMessages() {
        messages.removeAll()
        streamedContent = ""
        currentResponse = nil
        error = nil
    }

    /// Sets or updates the system message for the conversation.
    ///
    /// The system message helps set the behavior of the assistant. It's always
    /// placed at the beginning of the conversation.
    ///
    /// - Parameter message: The system message content.
    ///
    /// - Note: This replaces any existing system message.
    public func setSystemMessage(_ message: String) {
        // Remove any existing system messages
        messages.removeAll { $0.role == .system }

        // Insert system message at the beginning
        let systemMessage = ChatMessage(role: .system, content: .text(message))
        messages.insert(systemMessage, at: 0)
    }

    /// Generates embeddings for the provided texts.
    ///
    /// - Parameters:
    ///   - texts: Array of texts to generate embeddings for.
    ///   - model: The embedding model to use. Defaults to "text-embedding-ada-002".
    ///
    /// - Returns: Array of embedding vectors, one for each input text.
    ///   Returns an empty array if an error occurs.
    ///
    /// - Note: Check the `error` property if an empty array is returned.
    public func generateEmbeddings(for texts: [String], model: String = "text-embedding-ada-002")
        async -> [[Double]]
    {
        do {
            let response = try await Task.detached {
                try await self.api.createEmbedding(
                    EmbeddingRequest(
                        input: .array(texts),
                        model: model
                    )
                )
            }.value

            return response.data.map { $0.embedding }
        } catch {
            self.error = error
            return []
        }
    }

    /// Cancels any in-progress API request.
    ///
    /// Use this to stop long-running requests or streaming operations.
    /// The method immediately sets `isLoading` to false.
    public func cancelCurrentRequest() {
        currentTask?.cancel()
        isLoading = false
    }
}

// MARK: - Backward Compatibility

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
extension OpenAIObservable {
    @available(*, deprecated, message: "Use messages.last?.content instead")
    public var lastResponse: String? {
        if let lastMessage = messages.last,
            lastMessage.role == .assistant,
            case .text(let content) = lastMessage.content
        {
            return content
        }
        return nil
    }
}
