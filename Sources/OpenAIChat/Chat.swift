import Foundation
import OpenAICore

/// Helper type to encode/decode Any values.
///
/// This internal type provides a way to work with heterogeneous JSON data
/// by wrapping Swift's `Any` type in a Codable container.
///
/// - Note: Marked as @unchecked Sendable for JSON data handling.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}

/// Wrapper for JSON structured output to make it Sendable.
///
/// This type encapsulates JSON dictionary data in a thread-safe manner,
/// allowing structured JSON schemas to be passed in API requests.
public struct JSONStructuredOutputValue: Codable, Sendable {
    private let storage: AnyCodable

    public init(_ value: [String: Any]) {
        self.storage = AnyCodable(value)
    }

    public var value: [String: Any] {
        storage.value as? [String: Any] ?? [:]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.storage = try container.decode(AnyCodable.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

/// A request to create a chat completion.
///
/// This structure contains all the parameters needed to generate a chat completion
/// from OpenAI's language models.
///
/// ## Example
/// ```swift
/// let request = ChatRequest(
///     model: "gpt-3.5-turbo",
///     messages: [
///         ChatMessage(role: .system, content: .text("You are a helpful assistant.")),
///         ChatMessage(role: .user, content: .text("Hello!"))
///     ],
///     temperature: 0.7
/// )
/// ```
public struct ChatRequest: Codable, Sendable {
    /// ID of the model to use (e.g., "gpt-3.5-turbo", "gpt-4").
    public let model: String

    /// The messages to generate chat completions for.
    public let messages: [ChatMessage]

    /// Sampling temperature between 0 and 2. Higher values make output more random.
    public let temperature: Double?

    /// Nucleus sampling parameter. Alternative to temperature.
    public let topP: Double?

    /// Number of chat completion choices to generate.
    public let n: Int?

    /// Whether to stream partial message deltas.
    public let stream: Bool?

    /// Sequences where the API will stop generating further tokens.
    public let stop: TextInput?

    /// Maximum number of tokens to generate.
    public let maxTokens: Int?

    /// Penalizes new tokens based on whether they appear in the text so far.
    public let presencePenalty: Double?

    /// Penalizes new tokens based on their existing frequency in the text.
    public let frequencyPenalty: Double?

    /// Modify the likelihood of specified tokens appearing in the completion.
    public let logitBias: [String: Int]?

    /// A unique identifier representing your end-user.
    public let user: String?

    /// Format that the model must output (e.g., JSON mode).
    public let responseFormat: ResponseFormat?

    /// System fingerprint for deterministic sampling.
    public let seed: Int?

    /// Functions the model may call.
    public let tools: [ChatTool]?

    /// Controls which (if any) function is called by the model.
    public let toolChoice: ToolChoice?

    /// Whether to enable parallel function calling.
    public let parallelToolCalls: Bool?

    /// Creates a new chat completion request.
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stream: Bool? = nil,
        stop: TextInput? = nil,
        maxTokens: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Int]? = nil,
        user: String? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        tools: [ChatTool]? = nil,
        toolChoice: ToolChoice? = nil,
        parallelToolCalls: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stream = stream
        self.stop = stop
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.user = user
        self.responseFormat = responseFormat
        self.seed = seed
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
    }

    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature, n, stream, stop, user, seed, tools
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case responseFormat = "response_format"
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
    }
}

/// A message in a chat conversation.
///
/// Chat messages represent the conversation history between the user, assistant,
/// system, and tools. Each message has a role and content.
///
/// ## Example
/// ```swift
/// // System message to set behavior
/// ChatMessage(role: .system, content: .text("You are a helpful assistant."))
///
/// // User message
/// ChatMessage(role: .user, content: .text("What's the weather like?"))
///
/// // Assistant response
/// ChatMessage(role: .assistant, content: .text("I'd be happy to help..."))
/// ```
public struct ChatMessage: Codable, Sendable {
    /// The role of the message author.
    public let role: Role

    /// The content of the message.
    public let content: Content?

    /// An optional name for the participant.
    public let name: String?

    /// Tool calls generated by the model.
    public let toolCalls: [ToolCall]?

    /// ID of the tool call this message is responding to.
    public let toolCallId: String?

    /// Refusal reason if the model refused to respond.
    public let refusal: String?

    /// Annotations for the message.
    public let annotations: [String]?

    /// Optional audio response produced by the model.
    public let audio: AudioOutput?

    /// Creates a new chat message.
    public init(
        role: Role,
        content: Content? = nil,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil,
        refusal: String? = nil,
        annotations: [String]? = nil,
        audio: AudioOutput? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.refusal = refusal
        self.annotations = annotations
        self.audio = audio
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, name, refusal, annotations, audio
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

/// The role of a message author in a conversation.
public enum Role: String, Codable, Sendable {
    /// System messages set the behavior of the assistant.
    case system

    /// Messages from the end user.
    case user

    /// Messages from the AI assistant.
    case assistant

    /// Results from tool/function calls.
    case tool
}

/// The content of a chat message.
///
/// Content can be either plain text or an array of content parts
/// (for multimodal inputs like text + images).
public enum Content: Codable, Sendable {
    /// Plain text content.
    case text(String)

    /// Multimodal content with multiple parts.
    case parts([ContentPart])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.typeMismatch(
                Content.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [ContentPart]"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

/// A part of multimodal message content.
///
/// Content parts allow messages to contain mixed media types,
/// such as text and images together.
public enum ContentPart: Codable, Sendable {
    /// Text content part.
    case text(TextContent)

    /// Image content part.
    case image(ImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "image_url":
            self = .image(try ImageContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .image(let content):
            try content.encode(to: encoder)
        }
    }
}

/// Text content within a multimodal message.
///
/// Represents a text segment when using multimodal content parts.
public struct TextContent: Codable, Sendable {
    /// The content type, always "text".
    public let type: String

    /// The actual text content.
    public let text: String

    public init(text: String) {
        self.type = "text"
        self.text = text
    }
}

/// Image content within a multimodal message.
///
/// Represents an image reference when using multimodal content parts.
public struct ImageContent: Codable, Sendable {
    /// The content type, always "image_url".
    public let type: String

    /// The image URL and optional detail level.
    public let imageUrl: ImageURL

    public init(imageUrl: ImageURL) {
        self.type = "image_url"
        self.imageUrl = imageUrl
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case imageUrl = "image_url"
    }
}

/// Image URL reference with optional detail level.
///
/// Used to specify images in multimodal messages.
public struct ImageURL: Codable, Sendable {
    /// The URL of the image (can be a data URL or web URL).
    public let url: String

    /// The detail level for image processing (e.g., "low", "high", "auto").
    public let detail: String?

    public init(url: String, detail: String? = nil) {
        self.url = url
        self.detail = detail
    }
}

/// Specifies the format for model responses.
///
/// Controls whether the model outputs plain text, JSON objects,
/// or structured JSON following a specific schema.
public struct ResponseFormat: Codable, Sendable {
    /// The response format type.
    public let type: ResponseFormatType

    /// Optional JSON schema for structured output.
    public let jsonStructuredOutput: JSONStructuredOutput?

    public init(type: ResponseFormatType, jsonStructuredOutput: JSONStructuredOutput? = nil) {
        self.type = type
        self.jsonStructuredOutput = jsonStructuredOutput
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonStructuredOutput = "json_schema"
    }
}

/// The type of response format.
public enum ResponseFormatType: String, Codable, Sendable {
    /// Plain text response (default).
    case text

    /// JSON object response (model outputs valid JSON).
    case jsonObject = "json_object"

    /// Structured JSON response following a schema.
    case jsonStructuredOutput = "json_schema"
}

/// JSON schema definition for structured output.
///
/// Defines a JSON schema that the model's output must conform to
/// when using structured output mode.
public struct JSONStructuredOutput: Codable, Sendable {
    /// The name of the schema.
    public let name: String

    /// The JSON schema definition.
    private let structuredOutputValue: JSONStructuredOutputValue

    /// Whether to strictly enforce the schema.
    public let strict: Bool?

    public var structuredOutput: [String: Any] {
        structuredOutputValue.value
    }

    public init(name: String, structuredOutput: [String: Any], strict: Bool? = nil) {
        self.name = name
        self.structuredOutputValue = JSONStructuredOutputValue(structuredOutput)
        self.strict = strict
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict)

        let structuredOutputData = try container.decode(Data.self, forKey: .structuredOutput)
        let structuredOutput =
            try JSONSerialization.jsonObject(with: structuredOutputData, options: [])
            as? [String: Any] ?? [:]
        self.structuredOutputValue = JSONStructuredOutputValue(structuredOutput)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(strict, forKey: .strict)
        try container.encode(structuredOutputValue, forKey: .structuredOutput)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case structuredOutput = "schema"
        case strict
    }
}

/// A tool that the model can use.
///
/// Currently only function tools are supported, allowing the model
/// to call functions with structured inputs.
public struct ChatTool: Codable, Sendable {
    /// The type of tool (currently only "function" is supported).
    public let type: ToolType

    /// The function definition.
    public let function: FunctionDefinition

    public init(type: ToolType = .function, function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// The type of tool available to the model.
public enum ToolType: String, Codable, Sendable {
    /// Function tool type.
    case function
}

/// Definition of a function that can be called by the model.
///
/// Describes a function including its name, description, and parameter schema.
public struct FunctionDefinition: Codable, Sendable {
    /// The name of the function.
    public let name: String

    /// A description of what the function does.
    public let description: String?

    /// The parameters schema as a JSON schema object.
    private let parametersValue: JSONStructuredOutputValue?

    /// Whether to strictly validate parameters.
    public let strict: Bool?

    public var parameters: [String: Any]? {
        parametersValue?.value
    }

    public init(
        name: String, description: String? = nil, parameters: [String: Any]? = nil,
        strict: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.parametersValue = parameters.map { JSONStructuredOutputValue($0) }
        self.strict = strict
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict)

        if let parametersData = try container.decodeIfPresent(Data.self, forKey: .parameters) {
            let params =
                try JSONSerialization.jsonObject(with: parametersData, options: [])
                as? [String: Any]
            self.parametersValue = params.map { JSONStructuredOutputValue($0) }
        } else {
            self.parametersValue = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(strict, forKey: .strict)
        try container.encodeIfPresent(parametersValue, forKey: .parameters)
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, parameters, strict
    }
}

/// Controls which tool(s) the model can call.
public enum ToolChoice: Codable, Sendable {
    /// The model will not call any tools.
    case none

    /// The model can choose to call tools or not (default).
    case auto

    /// The model must call at least one tool.
    case required

    /// The model must call the specified function.
    case function(name: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default:
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unknown tool choice: \(string)")
            }
        } else if let object = try? container.decode(ToolChoiceFunction.self) {
            self = .function(name: object.function.name)
        } else {
            throw DecodingError.typeMismatch(
                ToolChoice.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or ToolChoiceFunction"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            try container.encode(ToolChoiceFunction(type: "function", function: .init(name: name)))
        }
    }
}

private struct ToolChoiceFunction: Codable {
    let type: String
    let function: FunctionName

    struct FunctionName: Codable {
        let name: String
    }
}

/// The response from a chat completion request.
///
/// Contains the generated message(s) along with metadata about the request.
public struct ChatResponse: Codable, Sendable {
    /// Unique identifier for the chat completion.
    public let id: String

    /// Object type, always "chat.completion".
    public let object: String

    /// Unix timestamp when the completion was created.
    public let created: Int

    /// The model used for the completion.
    public let model: String

    /// List of generated completions.
    public let choices: [Choice]

    /// Token usage statistics for the request.
    public let usage: Usage?

    /// System fingerprint for the completion.
    public let systemFingerprint: String?

    /// Service tier used for the completion.
    public let serviceTier: String?

    private enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
        case serviceTier = "service_tier"
    }

    /// A single completion choice.
    public struct Choice: Codable, Sendable {
        /// The index of this choice in the array.
        public let index: Int

        /// The generated message.
        public let message: ChatMessage

        /// Log probabilities for the output tokens.
        public let logprobs: LogProbs?

        /// Why the model stopped generating (e.g., "stop", "length", "tool_calls").
        public let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case index, message, logprobs
            case finishReason = "finish_reason"
        }
    }
}

/// A streaming response chunk from a chat completion request.
///
/// When streaming is enabled, the response is sent as a series of chunks
/// containing partial message deltas.
public struct ChatCompletionStreamResponse: Codable, Sendable {
    /// Unique identifier for the chat completion.
    public let id: String

    /// Object type, always "chat.completion.chunk".
    public let object: String

    /// Unix timestamp when the chunk was created.
    public let created: Int

    /// The model used for the completion.
    public let model: String

    /// List of choice deltas.
    public let choices: [StreamChoice]

    /// Token usage (only in final chunk).
    public let usage: Usage?

    /// System fingerprint for the completion.
    public let systemFingerprint: String?

    private enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
    }

    /// A single completion choice in a streaming response.
    public struct StreamChoice: Codable, Sendable {
        /// The index of this choice in the array.
        public let index: Int

        /// The message delta for this chunk.
        public let delta: ChatMessageDelta

        /// Log probabilities for this chunk.
        public let logprobs: LogProbs?

        /// Why the model stopped generating (only in final chunk).
        public let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case index, delta, logprobs
            case finishReason = "finish_reason"
        }
    }
}

/// Incremental message content in a streaming response.
///
/// Contains partial updates to a message during streaming.
public struct ChatMessageDelta: Codable, Sendable {
    /// The role of the message author (may be partial).
    public let role: Role?

    /// Partial message content.
    public let content: String?

    /// Partial tool calls.
    public let toolCalls: [ToolCallDelta]?

    /// Optional audio response produced by the model.
    public let audio: AudioOutput?

    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case audio
    }
}

/// A tool call made by the model.
///
/// Represents the model's request to invoke a specific tool/function.
public struct ToolCall: Codable, Sendable {
    /// Unique identifier for this tool call.
    public let id: String

    /// The type of tool being called.
    public let type: ToolType

    /// The function call details.
    public let function: FunctionCall

    public init(id: String, type: ToolType = .function, function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Details of a function call.
///
/// Contains the function name and JSON-encoded arguments.
public struct FunctionCall: Codable, Sendable {
    /// The name of the function to call.
    public let name: String

    /// The function arguments as a JSON string.
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// A partial tool call in a streaming response.
///
/// Represents incremental updates to tool calls during streaming.
public struct ToolCallDelta: Codable, Sendable {
    /// The index of this tool call in the array.
    public let index: Int

    /// The tool call ID (may be partial).
    public let id: String?

    /// The tool type (may be partial).
    public let type: ToolType?

    /// The function call delta.
    public let function: FunctionCallDelta?
}

/// Partial function call information in a streaming response.
///
/// Contains incremental updates to function name and arguments.
public struct FunctionCallDelta: Codable, Sendable {
    /// Partial function name.
    public let name: String?

    /// Partial function arguments.
    public let arguments: String?
}

/// Token usage statistics for a completion request.
///
/// Provides a breakdown of token consumption for billing and limit tracking.
public struct Usage: Codable, Sendable {
    /// Number of tokens in the prompt (`prompt_tokens`) or input (`input_tokens`).
    public let promptTokens: Int?

    /// Number of tokens in the completion (`completion_tokens`) or output (`output_tokens`).
    public let completionTokens: Int?

    /// Total tokens used (prompt + completion or input + output).
    public let totalTokens: Int?

    /// Detailed breakdown of prompt / input tokens.
    public let promptTokensDetails: TokenDetails?

    /// Detailed breakdown of completion / output tokens.
    public let completionTokensDetails: TokenDetails?

    /// Some endpoints use `input_tokens` / `output_tokens`.
    public let inputTokens: Int?
    public let outputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    // Provide computed properties for a unified view
    public var effectivePromptTokens: Int? { promptTokens ?? inputTokens }
    public var effectiveCompletionTokens: Int? { completionTokens ?? outputTokens }
}

/// Detailed token usage information.
public struct TokenDetails: Codable, Sendable {
    /// Number of cached tokens used.
    public let cachedTokens: Int?

    /// Number of audio tokens used.
    public let audioTokens: Int?

    /// Number of reasoning tokens used.
    public let reasoningTokens: Int?

    /// Number of accepted prediction tokens.
    public let acceptedPredictionTokens: Int?

    /// Number of rejected prediction tokens.
    public let rejectedPredictionTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
        case reasoningTokens = "reasoning_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case rejectedPredictionTokens = "rejected_prediction_tokens"
    }
}

/// Log probability information for generated tokens.
///
/// Contains detailed probability information about token generation.
public struct LogProbs: Codable, Sendable {
    /// Array of token log probabilities.
    public let content: [TokenLogProb]?
}

/// Log probability information for a single token.
///
/// Contains the token, its log probability, and alternative tokens.
public struct TokenLogProb: Codable, Sendable {
    /// The generated token.
    public let token: String

    /// The log probability of this token.
    public let logprob: Double

    /// UTF-8 byte representation of the token.
    public let bytes: [Int]?

    /// Top alternative tokens and their probabilities.
    public let topLogprobs: [TopLogProb]

    private enum CodingKeys: String, CodingKey {
        case token, logprob, bytes
        case topLogprobs = "top_logprobs"
    }
}

/// Alternative token with its log probability.
///
/// Represents a token that could have been generated instead.
public struct TopLogProb: Codable, Sendable {
    /// The alternative token.
    public let token: String

    /// The log probability of this token.
    public let logprob: Double

    /// UTF-8 byte representation of the token.
    public let bytes: [Int]?
}

/// Details of an audio output returned by the model.
public struct AudioOutput: Codable, Sendable {
    /// A unique identifier for this audio chunk.
    public let id: String?

    /// Base-64 encoded audio data (when not streaming) or partial data during streaming.
    public let data: String?

    /// Unix timestamp (seconds) when the audio URL or data expires.
    public let expiresAt: Int?

    /// Transcript for the audio response (if present).
    public let transcript: String?

    private enum CodingKeys: String, CodingKey {
        case id, data, transcript
        case expiresAt = "expires_at"
    }
}

// MARK: - Backward compatibility type aliases

@available(*, deprecated, renamed: "JSONStructuredOutput")
public typealias JSONSchema = JSONStructuredOutput

@available(*, deprecated, renamed: "JSONStructuredOutputValue")
public typealias JSONSchemaValue = JSONStructuredOutputValue
